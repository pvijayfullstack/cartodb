class CommonData

  def initialize
    @datasets = nil
  end

  def datasets
    if @datasets.nil?

      _datasets = DATASETS_EMPTY

      if is_enabled
        _datasets = get_datasets(get_datasets_json, DATASETS_EMPTY)
      end

      @datasets = {
        :datasets => _datasets,
        :categories => get_categories(_datasets)
      }
    end

    @datasets
  end

  private

  def get_datasets(json, default)
    begin
      _datasets = JSON.parse(json).fetch('rows', default)
    rescue
      _datasets = default
    end
    _datasets.map { |dataset|
      dataset['url'] = export_url(dataset['tabname'])
      dataset
    }
  end

  def get_categories(datasets)
    categories = {}
    datasets.each { |dataset|
      unless categories.has_key?(dataset['category'])
        categories[dataset['category']] = {
            :name => dataset['category'],
            :image_url => dataset['category_image_url'],
            :count => 0
        }
      end
      categories[dataset['category']][:count] += 1
    }
    categories.values
  end

  def get_datasets_json
    body = nil
    begin
      response = Typhoeus.get(datasets_url, followlocation:true)
      if response.code == 200
        body = response.response_body
      end
    rescue
      body = nil
    end
    body
  end

  def base_url
    "#{config('protocol', 'https')}://#{config('username')}.#{config('host')}/api/v1"
  end

  def datasets_url
    sql_authenticated_api_url sql_api_url(DATASETS_QUERY)
  end

  def export_url(table_name)
    "#{sql_api_url export_query(table_name)}&filename=#{table_name}&format=#{config('format', 'shp')}"
  end

  def sql_api_url(query)
    "#{base_url}/sql?q=#{URI::encode query}"
  end

  def sql_authenticated_api_url(sql_api_url)
    "#{sql_api_url}&api_key=#{config('api_key')}"
  end

  def export_query(table_name)
    "select * from #{table_name}"
  end

  def is_enabled
    !config('username').nil? && !config('api_key').nil?
  end

  def config(key, default=nil)
    if Cartodb.config[:common_data].present?
      Cartodb.config[:common_data][key].present? ? Cartodb.config[:common_data][key] : default
    else
      default
    end
  end

  DATASETS_EMPTY = {
      :datasets => [],
      :categories => []
  }

  DATASETS_QUERY = <<-query
select
    meta_dataset.name,
    meta_dataset.tabname,
    meta_dataset.created_at,
    meta_dataset.updated_at,
    meta_dataset.description,
    (
        SELECT reltuples
        FROM pg_class C LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
        WHERE
            nspname NOT IN ('pg_catalog', 'information_schema')
            AND relkind='r'
            AND relname = meta_dataset.tabname
    ) as rows,
    pg_relation_size(meta_dataset.tabname) size,
    meta_dataset.source,
    meta_dataset.license,
    meta_category.name category,
    meta_category.image_url category_image_url
from meta_dataset, meta_category
where meta_dataset.meta_category_id = meta_category.cartodb_id
  query

end


class CommonDataSingleton
  include Singleton

  def initialize
    @common_data = CommonData.new
    @last_usage = Time.now
  end

  def datasets
    now = Time.now
    if now - @last_usage > (60 * 60)
      @common_data = CommonData.new
      @last_usage = now
    end
    @common_data.datasets
  end
end
