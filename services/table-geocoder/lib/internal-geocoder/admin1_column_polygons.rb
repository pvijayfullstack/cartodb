# encoding: utf-8

require_relative 'abstract_query_generator'

module CartoDB
  module InternalGeocoder

    class Admin1ColumnPolygons < AbstractQueryGenerator

      def search_terms_query(page)
        %Q{
          SELECT DISTINCT
            quote_nullable(trim(#{@internal_geocoder.column_name})) as region,
            quote_nullable(trim(#{@internal_geocoder.country_column})) as country
          FROM #{@internal_geocoder.qualified_table_name}
          WHERE cartodb_georef_status IS NULL
          LIMIT #{@internal_geocoder.batch_size} OFFSET #{page * @internal_geocoder.batch_size}
        }
      end

      def dataservices_query(search_terms)
        region = search_terms.map { |row| row[:region] }.join(',')
        countries = search_terms.map { |row| row[:country] }.join(',')
        "WITH geo_function AS (SELECT (geocode_admin1_polygons(Array[#{region}], Array[#{countries}])).*) SELECT q, c, geom, success FROM geo_function"
      end

      def copy_results_to_table_query
        %Q{
          UPDATE #{@internal_geocoder.qualified_table_name} AS dest
          SET the_geom = orig.the_geom, cartodb_georef_status = orig.cartodb_georef_status
          FROM #{@internal_geocoder.temp_table_name} AS orig
          WHERE trim(dest.#{@internal_geocoder.column_name}::text) = orig.geocode_string
            AND trim(dest.#{@internal_geocoder.country_column}::text) = orig.country
            AND dest.cartodb_georef_status IS NULL
        }
      end

    end # CitiesTextPoints

  end # InternalGeocoder
end # CartoDB
