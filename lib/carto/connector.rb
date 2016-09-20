# encoding: utf-8

require_relative 'connector/fdw_support'
require_relative 'connector/errors'
require_relative 'connector/providers'
require_relative 'connector/parameters'

module Carto
  # This class provides remote database connection services based on FDW
  class Connector

    attr_reader :name

    def initialize(parameters, options = {})
      @logger     = options[:logger]
      @user       = options[:user]

      @unique_suffix = UUIDTools::UUID.timestamp_create.to_s.delete('-') # .to_i.to_s(16) # or hash from user, etc.
      @params = Parameters.new(parameters)

      @name = @params[:provider]
      @name ||= DEFAULT_PROVIDER

      raise InvalidParametersError.new("Provider not defined") if @name.blank?
      @provider = Connector.provider_class(@name).try :new, @params
      raise InvalidParametersError.new("Invalid provider: #{@name}") if @provider.blank?
    end

    def copy_table(schema_name:, table_name:)
      log "Connector Copy table  #{schema_name}.#{table_name}"
      validate!
      # TODO: logging with CartoDB::Logger
      with_server do
        begin
          qualified_table_name = %{"#{schema_name}"."#{table_name}"}
          foreign_table_name = @provider.foreign_table_name(foreign_prefix)
          log "Creating Foreign Table"
          execute_as_superuser create_foreign_table_command
          log "Copying Foreign Table"
          max_rows = limits[:max_rows]
          execute copy_foreign_table_command(
            qualified_table_name, qualified_foreign_table_name(foreign_table_name), max_rows
          )
          check_copied_table_size(qualified_table_name, max_rows)
        ensure
          execute_as_superuser drop_foreign_table_command(foreign_table_name) if foreign_table_name
        end
      end
    end

    def list_tables
      # TODO: validate! only: [:connection] # we need to implement partial connector validation
      with_server do
        tables = execute %{
          SELECT * FROM ODBCTablesList('#{server_name}');
        }
        tables.to_a
      end
    end

    def remote_data_updated?
      # TODO: can we detect if query results have changed?
      true
    end

    def remote_table_name
      @provider.table_name
    end

    # General availabillity check
    def self.check_availability!(user)
      unless user.has_feature_flag?('carto-connectors')
        raise ConnectorsDisabledError.new(user: user)
      end
    end

    # Check availability for a user and provider
    def check_availability!
      Connector.check_availability!(@user)
      if !available?
        raise ConnectorsDisabledError.new(user: @user, provider: @name)
      end
    end

    # Limits for the user/provider
    def limits
      Connector.limits provider: @name, user: @user
    end

    # Availability for the user/provider
    def available?
      limits[:available]
    end

    def self.limits(provider:, user:)
      # Load general application defaults
      available = Cartodb.get_config(:connectors, provider, 'available') || false
      max_rows  = Cartodb.get_config(:connectors, provider, 'max_rows')

      # TODO: now we should override these values with organization defaults (for org users),
      #       then with existing user specific limits

      { available: available, max_rows: max_rows }
    end

    # Information about a connector's features and parameters.
    #
    # Example:
    # {
    #   'mysql' => {
    #     features: {
    #                 "sql_queries":    true,
    #                 "list_databases": false,
    #                 "list_tables":    true,
    #                 "preview_table":  false
    #     },
    #     parameters: {
    #       connection: {
    #         server: { required: true, description: "..." },
    #         ...
    #       },
    #       table: { required: true, description: "..." },
    #       ...
    #     }
    #   }, ...
    # }
    def self.information(provider_name, user = nil)
      provider = provider_class(provider_name)
      raise InvalidParametersError.new("Invalid provider: #{provider_name}") if provider.blank?
      provider.information
    end

    # Available providers information.
    #
    # Example:
    # {
    #   'mysql' => { name: 'MySQL', description: '...', available: true },
    #   ...
    # }
    def self.providers(user = nil)
      providers_info = {}
      provider_ids.each do |id|
        next unless provider_public?(id)
        # TODO: load description template for provider id
        description = nil
        if user
          available = Connector.limits(user: user, provider: name)[:available]
        end
        providers_info[id] = {
          name:        provider_name(id),
          description: description,
          available:   available
        }
      end
      providers_info
    end

    private

    # Execute code that requires a FDW server/user mapping
    # The server name is given by the method `#server_name`
    def with_server
      # Currently we create temporary server and user mapings when we need them,
      # and drop them after use.
      log "Creating Server"
      execute_as_superuser create_server_command
      log "Creating Usermap"
      execute_as_superuser create_usermap_command
      yield
    rescue => error
      log "Connector Error #{error}"
      raise error
    ensure
      log "Connector cleanup"
      execute_as_superuser drop_usermap_command
      execute_as_superuser drop_server_command
      log "Connector cleaned-up"
    end

    def validate!
      @provider.validate!
    end

    def log(message, truncate = true)
      @logger.append message, truncate if @logger
    end

    MAX_PG_IDENTIFIER_LEN = 60
    MIN_TAB_ID_LEN        = 10

    def server_name
      max_len = MAX_PG_IDENTIFIER_LEN - @unique_suffix.size - MIN_TAB_ID_LEN - 1
      connector_name = Carto::DB::Sanitize.sanitize_identifier @name
      connector_name[0...max_len]
      "#{connector_name.downcase}_#{@unique_suffix}"
    end

    def foreign_prefix
      "#{server_name}_"
    end

    def foreign_table_schema
      # since connectors' foreign table names are unique (because
      # server names are unique and not reused)
      # we could in principle use any schema (@schema, 'public', 'cdb_importer')
      CartoDB::Connector::Importer::ORIGIN_SCHEMA
    end

    def qualified_foreign_table_name(foreign_table_name)
      %{"#{foreign_table_schema}"."#{foreign_table_name}"}
    end

    def create_server_command
      @provider.create_server_command server_name
    end

    def create_usermap_command
      [
        @provider.create_usermap_command(server_name, @user.database_username),
        @provider.create_usermap_command(server_name, 'postgres')
      ].join("\n")
    end

    def create_foreign_table_command
      @provider.create_foreign_table_command server_name, foreign_table_schema,
                                             foreign_prefix,
                                             @user.database_username
    end

    def drop_server_command
      @provider.drop_server_command server_name
    end

    def drop_usermap_command
      [
        @provider.drop_usermap_command(server_name, 'postgres'),
        @provider.drop_usermap_command(server_name, @user.database_username)
      ].join("\n")
    end

    def drop_foreign_table_command(foreign_table_name)
      @provider.drop_foreign_table_command foreign_table_schema, foreign_table_name
    end

    def copy_foreign_table_command(local_table_name, foreign_table_name, max_rows)
      limit = (max_rows && max_rows > 0) ? " LIMIT #{max_rows}" : ''
      %{
        CREATE TABLE #{local_table_name}
          AS SELECT * FROM #{foreign_table_name}
            #{limit};
      }
    end

    def execute_as_superuser(command)
      # TODO: instead of selectict here fetch/execute, let the caller choose the method
      if command =~ /\A\s*SELECT/mi
        @user.in_database(as: :superuser).fetch command
      else
        @user.in_database(as: :superuser).execute command
      end
    end

    def execute(command)
      # TODO: instead of selectict here fetch/execute, let the caller choose the method
      if command =~ /\A\s*SELECT/mi
        @user.in_database.fetch command
      else
        @user.in_database.execute command
      end
    end

    def check_copied_table_size(table_name, max_rows)
      warnings = {}
      if max_rows && max_rows > 0
        num_rows = execute(%{
          SELECT count(*) as num_rows FROM #{table_name};
        }).first['num_rows']
        if num_rows == max_rows
          # The maximum number of rows per connection was reached
          warnings[:max_rows_per_connection] = max_rows
        end
      end
      warnings
    end
  end
end
