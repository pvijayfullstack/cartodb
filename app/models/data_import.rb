# encoding: UTF-8'
require 'sequel'
require 'fileutils'
require 'uuidtools'
require_relative './user'
require_relative './table'
require_relative './table_registrar'
require_relative './quota_checker'
require_relative '../../lib/cartodb/errors'
require_relative '../../lib/cartodb/metrics'
require_relative '../../lib/cartodb_stats'
require_relative '../../services/track_record/track_record/log'
require_relative '../../config/initializers/redis'
require_relative '../../services/importer/lib/importer'
require_relative '../connectors/importer'

require_relative '../../services/importer/lib/importer/datasource_downloader'
require_relative '../../services/datasources/lib/datasources'
include CartoDB::Datasources

class DataImport < Sequel::Model
  REDIS_LOG_KEY_PREFIX          = 'importer'
  REDIS_LOG_EXPIRATION_IN_SECS  = 3600 * 24 * 2 # 2 days
  MERGE_WITH_UNMATCHING_COLUMN_TYPES_RE = /No .*matches.*argument type.*/

  attr_accessor   :log, :results

  PUBLIC_ATTRIBUTES = %W{ id user_id table_id data_type table_name state
    error_code queue_id get_error_text tables_created_count
    synchronization_id service_name service_item_id }

  STATE_SUCCESS   = 'complete'
  STATE_UPLOADING = 'uploading'
  STATE_FAILURE   = 'failure'

  def after_initialize
    instantiate_log
    self.results  = []
    self.state    ||= STATE_UPLOADING
  end #after_initialize

  def before_save
    self.logger = self.log.id unless self.logger.present?
    self.updated_at = Time.now
  end

  def dataimport_logger
    @@dataimport_logger ||= Logger.new("#{Rails.root}/log/imports.log")
  end

  def public_values
    values = Hash[PUBLIC_ATTRIBUTES.map{ |attribute| [attribute, send(attribute)] }]
    values.merge!('queue_id' => id)
    values.merge!(success: success) if (state == STATE_SUCCESS || state == STATE_FAILURE)
    values
  end

  def run_import!
    log.append "Running on server #{Socket.gethostname} with PID: #{Process.pid}"
    begin
      success = !!dispatch
    rescue TokenExpiredOrInvalidError => ex
      success = false
      begin
        current_user.oauths.remove(ex.service_name)
      rescue => ex2
        log.append "Exception removing OAuth: #{ex2.message}"
        log.append ex2.backtrace
      end
    end

    log.append 'After dispatch'
    if self.results.empty?
      self.error_code = 1002
      self.state      = STATE_FAILURE
      save
      return self
    end

    success ? handle_success : handle_failure
    Rails.logger.debug log.to_s
    self
  rescue => exception
    log.append "Exception: #{exception.to_s}"
    log.append exception.backtrace
    stacktrace = exception.to_s + exception.backtrace.join
    Rollbar.report_message('Import error', 'error', error_info: stacktrace)
    handle_failure
    self
  end

  def get_error_text
    self.error_code.blank? ? CartoDB::IMPORTER_ERROR_CODES[99999] : CartoDB::IMPORTER_ERROR_CODES[self.error_code]
  end

  def raise_over_table_quota_error
    log.append 'Over account table limit, please upgrade'
    self.error_code = 8002
    self.state      = STATE_FAILURE
    save
    raise CartoDB::QuotaExceeded, 'More tables required'
  end

  def mark_as_failed_if_stuck!
    return false unless stuck?

    log.append "Import timed out. Id:#{self.id} State:#{self.state} Created at:#{self.created_at} Running imports:#{running_import_ids}"

    self.success  = false
    self.state    = STATE_FAILURE
    save

    CartoDB::notify_exception(
      CartoDB::Importer2::GenericImportError.new('Import timed out'),
      user: current_user
    )
    true
  end

  def data_source=(data_source)
    if File.exist?(Rails.root.join("public#{data_source}"))
      self.values[:data_type] = 'file'
      self.values[:data_source] = Rails.root.join("public#{data_source}").to_s
    elsif Addressable::URI.parse(data_source).host.present?
      self.values[:data_type] = 'url'
      self.values[:data_source] = data_source
    end
    # else SQL-based import
  end

  def remove_uploaded_resources
    return nil unless uploaded_file

    path = Rails.root.join('public', 'uploads', uploaded_file[1])
    FileUtils.rm_rf(path) if Dir.exists?(path)
  end #remove_uploaded_resources

  def handle_success
    CartodbStats.increment_imports
    self.success  = true
    self.state    = STATE_SUCCESS
    log.append "Import finished\n"
    save
    notify(results)
    self
  end

  def handle_failure
    self.success    = false
    self.state      = STATE_FAILURE
    log.append "ERROR!\n"
    self.save
    notify(results)
    self
  rescue => exception
    log.append "Exception: #{exception.to_s}"
    log.append exception.backtrace
    self
  end

  def table
    # We can assume the owner is always who imports the data
    # so no need to change to a Visualization::Collection based load
    ::Table.where(id: table_id, user_id: user_id).first
  end

  private

  def dispatch
    return migrate_existing   if migrate_table.present?
    return from_table         if table_copy.present? || from_query.present?
    new_importer
  rescue => exception
    puts exception.to_s + exception.backtrace.join("\n")
    raise
  end

  def running_import_ids
    Resque::Worker.all.map do |worker|
      next unless worker.job['queue'] == 'imports'
      worker.job['payload']['args'].first['job_id'] rescue nil
    end.compact
  end

  def public_url
    return data_source unless uploaded_file
    "https://#{current_user.username}.cartodb.com/#{uploaded_file[0]}"
  end

  def valid_uuid?(text)
    !!UUIDTools::UUID.parse(text)
  rescue TypeError
    false
  rescue ArgumentError
    false
  end

  def before_destroy
    self.remove_uploaded_resources
  end

  def instantiate_log
    uuid = self.logger

    if valid_uuid?(uuid)
      self.log  = TrackRecord::Log.new(
        id:         uuid.to_s,
        prefix:     REDIS_LOG_KEY_PREFIX,
        expiration: REDIS_LOG_EXPIRATION_IN_SECS
      ).fetch
    else
      self.log  = TrackRecord::Log.new(
        prefix:     REDIS_LOG_KEY_PREFIX,
        expiration: REDIS_LOG_EXPIRATION_IN_SECS
      )
    end
  end

  def uploaded_file
    data_source.to_s.match(/uploads\/([a-z0-9]{20})\/.*/)
  end

  # A stuck job shouldn't be finished, so it's state should not
  # be complete nor failed, it should have been in the queue
  # for more than 5 minutes and it shouldn't be currently
  # processed by any active worker
  def stuck?
    !%w(complete failure).include?(self.state) &&
    self.created_at < 5.minutes.ago            &&
    !running_import_ids.include?(self.id)
  end

  def from_table
    log.append 'from_table()'

    number_of_tables = 1
    quota_checker = CartoDB::QuotaChecker.new(current_user)
    if quota_checker.will_be_over_table_quota?(number_of_tables)
      raise_over_table_quota_error
    end

    query = table_copy ? "SELECT * FROM #{table_copy}" : from_query
    new_table_name = import_from_query(table_name, query)

    self.update(table_names: new_table_name)
    migrate_existing(new_table_name)

    self.results.push CartoDB::Importer2::Result.new(success: true, error: nil)
  rescue Sequel::DatabaseError => exception
    if exception.to_s =~ MERGE_WITH_UNMATCHING_COLUMN_TYPES_RE
      set_merge_error(8004, exception.to_s)
    else
      set_merge_error(8003, exception.to_s)
    end
    false
  end

  def import_from_query(name, query)
    log.append 'import_from_query()'

    self.data_type    = 'query'
    self.data_source  = query
    self.save

    candidates =  current_user.tables.select_map(:name)
    table_name = ::Table.get_valid_table_name(name, {
        name_candidates: candidates,
        database_schema: current_user.database_schema
    })
    current_user.in_database.run(%Q{CREATE TABLE #{table_name} AS #{query}})
    if current_user.over_disk_quota?
      log.append "Over storage quota. Dropping table #{table_name}"
      current_user.in_database.run(%Q{DROP TABLE #{table_name}})
      self.error_code = 8001
      self.state      = STATE_FAILURE
      save
      raise CartoDB::QuotaExceeded, 'More storage required'
    end

    table_name
  end

  def migrate_existing(imported_name=migrate_table, name=nil)
    new_name = imported_name || name

    log.append 'migrate_existing()'

    table         = ::Table.new
    table.user_id = user_id
    table.name    = new_name
    table.migrate_existing_table = imported_name
    table.data_import_id = self.id

    if table.valid?
      log.append 'Table valid'
      table.save
      table.optimize
      table.map.recalculate_bounds!
      if current_user.remaining_quota < 0
        log.append 'Over storage quota, removing table'
        self.error_code = 8001
        self.state      = STATE_FAILURE
        save
        table.destroy
        raise CartoDB::QuotaExceeded, 'More storage required'
      end
      refresh
      self.table_id = table.id
      self.table_name = table.name
      save
      true
    else
      reload
      log.append "Table invalid: Error linking #{imported_name} to UI: " + table.errors.full_messages.join(' - ')
      false
    end
  end

  def pg_options
    Rails.configuration.database_configuration[Rails.env].symbolize_keys
      .merge(
        user:     current_user.database_username,
        password: current_user.database_password,
        database: current_user.database_name,
        host:     current_user.database_host
      ) {|key, o, n| n.nil? || n.empty? ? o : n}
  end

  def new_importer
    log.append 'new_importer()'

    datasource_provider = get_datasource_provider

    downloader = get_downloader(datasource_provider)

    tracker       = lambda { |state| self.state = state; save }
    runner        = CartoDB::Importer2::Runner.new(
                      pg_options, downloader, log, current_user.remaining_quota
                    )
    registrar     = CartoDB::TableRegistrar.new(current_user, ::Table)
    quota_checker = CartoDB::QuotaChecker.new(current_user)
    database      = current_user.in_database
    destination_schema = current_user.database_schema
    importer      = CartoDB::Connector::Importer.new(runner, registrar, quota_checker, database, id, destination_schema)
    log.append 'Before importer run'
    importer.run(tracker)
    log.append 'After importer run'

    self.results    = importer.results
    self.error_code = importer.error_code
    self.table_name = importer.table.name if importer.success? && importer.table
    self.table_id   = importer.table.id if importer.success? && importer.table

    # TODO: WIP for CDB-3936 (store)
    #puts runner.loader.class.to_s
    #puts runner.loader.source_file.extension

    update_synchronization(importer)

    importer.success? ? set_datasource_audit_to_complete(datasource_provider, \
                                                         importer.success? && importer.table ? importer.table.id : nil)
                      : set_datasource_audit_to_failed(datasource_provider)

    importer.success?
  end

  def update_synchronization(importer)
    if synchronization_id
      log.append "synchronization_id: #{synchronization_id}"
      synchronization = CartoDB::Synchronization::Member.new(id: synchronization_id).fetch
      synchronization.name    = self.table_name
      synchronization.log_id  = log.id

      if importer.success?
        synchronization.state = 'success'
        synchronization.error_code = nil
        synchronization.error_message = nil
      else
        synchronization.state = 'failure'
        synchronization.error_code = error_code
        synchronization.error_message = get_error_text
      end
      log.append "importer.success? #{synchronization.state}"
      synchronization.store
    end
  end

  def get_datasource_provider
    datasource_name = (service_name.nil? || service_name.size == 0) ? Url::PublicUrl::DATASOURCE_NAME : service_name
    if service_item_id.nil? || service_item_id.size == 0
      self.service_item_id = data_source
    end

    get_datasource(datasource_name, service_item_id)
  end

  def get_downloader(datasource_provider)
    log.append "Fetching datasource #{datasource_provider.to_s} metadata for item id #{service_item_id}"
    metadata = datasource_provider.get_resource_metadata(service_item_id)

    if datasource_provider.providers_download_url?
      downloader = CartoDB::Importer2::Downloader.new(
          (metadata[:url].present? && datasource_provider.providers_download_url?) ? metadata[:url] : data_source
      )
      log.append "File will be downloaded from #{downloader.url}"
    else
      log.append 'Downloading file data from datasource'
      downloader = CartoDB::Importer2::DatasourceDownloader.new(datasource_provider, metadata, {}, log)
    end

    downloader
  end

  def current_user
    @current_user ||= User[user_id]
  end

  def notify(results)
    owner = User.where(:id => self.user_id).first
    imported_tables = results.select {|r| r.success }.length
    failed_tables = results.length - imported_tables
    import_log = {'user' => owner.username, 
                  'state' => self.state, 
                  'tables' => results.length, 
                  'imported_tables' => imported_tables, 
                  'failed_tables' => failed_tables,
                  'error_code' => self.error_code,
                  'import_timestamp' => Time.now,
                  'queue_server' => `hostname`.strip,
                  'database_host' => owner.database_host
                 }
    dataimport_logger.info(import_log.to_json)

    results.each { |result| CartoDB::Metrics.new.report(:import, payload_for(result)) }
  end

  def payload_for(result=nil)
    payload = {
      file_url:       public_url,
      distinct_id:    current_user.username,
      username:       current_user.username,
      account_type:   current_user.account_type,
      database:       current_user.database_name,
      email:          current_user.email,
      log:            log.to_s
    }
    payload.merge!(
      name:           result.name,
      extension:      result.extension,
      success:        result.success,
      error_code:     result.error_code,
    ) if result
    payload.merge!(
      file_url_hostname: URI.parse(public_url).hostname
    ) if public_url rescue nil
    payload.merge!(error_title: get_error_text) if state == STATE_FAILURE
    payload
  end

  # @param datasource_name String
  # @param service_item_id String|nil
  # @return mixed|nil
  # @throws DataSourceError
  def get_datasource(datasource_name, service_item_id)
    begin
      oauth = current_user.oauths.select(datasource_name)
      # Tables metadata DB also store resque data
      datasource = DatasourcesFactory.get_datasource(datasource_name, current_user, $tables_metadata)
      datasource.report_component = Rollbar
      datasource.token = oauth.token unless oauth.nil?
    rescue => ex
      log.append "Exception: #{ex.message}"
      log.append ex.backtrace
      Rollbar.report_message('Import error: ', 'error', error_info: ex.message + ex.backtrace.join)
      raise CartoDB::DataSourceError.new("Datasource #{datasource_name} could not be instantiated")
    end
    if service_item_id.nil?
      raise CartoDB::DataSourceError.new("Datasource #{datasource_name} without item id")
    end

    if datasource.persists_state_via_data_import?
      datasource.data_import_item = self
    end

    datasource
  end

  def set_merge_error(error_code, log_info='')
    log.append("Going to set merge error with code #{error_code}")
    log.append("Additional error info: #{log_info}") unless log_info.empty?
    self.results = [CartoDB::Importer2::Result.new(
      success: false, error_code: error_code
    )]
    self.error_code = error_code
    self.state = STATE_FAILURE
  end

  def set_datasource_audit_to_complete(datasource, table_id = nil)
    if datasource.persists_state_via_data_import?
      datasource.data_import_item = self
      datasource.set_audit_to_completed(table_id)
    end
  end

  def set_datasource_audit_to_failed(datasource)
    if datasource.persists_state_via_data_import?
      datasource.data_import_item = self
      datasource.set_audit_to_failed
    end
  end

end

