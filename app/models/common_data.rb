require_relative '../../lib/carto/http/client'
require_relative '../../services/sql-api/sql_api'

class CommonData

  # seconds
  CONNECT_TIMEOUT = 45
  DEFAULT_TIMEOUT = 60

  def initialize(visualizations_api_url)
    @datasets = nil
    @http_client = Carto::Http::Client.get('common_data', log_requests: true)
    @visualizations_api_url = visualizations_api_url
  end

  def datasets

    if @datasets.nil?
      datasets = []
      if is_enabled?
        datasets = get_datasets(get_datasets_json)
      end
      @datasets = datasets
    end

    @datasets
  end

  def is_enabled?
    !config('username').nil?
  end

  private

  def get_datasets(json)
    begin
      rows = JSON.parse(json).fetch('visualizations', [])
    rescue => e
      CartoDB.notify_exception(e)
      rows = []
    end
    CartoDB.notify_error('common-data empty', { rows: rows }) if rows.nil? || rows.empty?

    datasets = []
    rows.each do |row|
      # Common-data's meta tables starts with meta_ and we want to avoid them
      next if row["name"] =~ /meta_/
      datasets << get_common_data_from_visualization(row)
    end
    datasets
  end

  def get_common_data_from_visualization(row)
      row_data = {}
      row_data["name"] = row["name"]
      row_data["display_name"] = row["display_name"].nil? ? row["name"] : row["display_name"]
      row_data["tabname"] = row["name"]
      row_data["description"] = row["description"]
      row_data["source"] = row["source"]
      row_data["license"] = row["license"]
      row_data["tags"] = row["tags"]
      row_data["geometry_types"] = %Q[{#{row["table"]["geometry_types"].join(',')}}]
      row_data["rows"] = row["table"]["row_count"]
      row_data["size"] = row["table"]["size"]
      row_data["url"] = export_url(row["name"])
      row_data["created_at"] = row["created_at"]
      row_data["updated_at"] = row["updated_at"]
      row_data
  end

  def get_datasets_json
    body = nil
    begin
      http_client = Carto::Http::Client.get('common_data', log_requests: true)
      response = http_client.request(
        @visualizations_api_url,
        method: :get,
        connecttimeout: CONNECT_TIMEOUT,
        timeout: DEFAULT_TIMEOUT,
      ).run
      if response.code == 200
        body = response.response_body
      end
    rescue
      body = nil
    end
    body
  end

  def export_url(table_name)
    query = "select * from #{table_name}"
    sql_api_url(query, table_name, config('format', 'shp'))
  end

  def sql_api_url(query, filename, format)
    common_data_base_url = config('base_url')
    CartoDB::SQLApi.new({
      base_url: common_data_base_url,
      protocol: 'https',
      username: config('username'),
    }).url(query, format, filename)
  end

  def config(key, default=nil)
    if Cartodb.config[:common_data].present?
      Cartodb.config[:common_data][key].present? ? Cartodb.config[:common_data][key] : default
    else
      default
    end
  end
end
