# encoding: utf-8
require_relative './column'
require_relative './job'

module CartoDB
  module Importer2
    class Georeferencer
      LATITUDE_POSSIBLE_NAMES   = %w{ latitude lat latitudedecimal
        latitud lati decimallatitude decimallat }
      LONGITUDE_POSSIBLE_NAMES  = %w{ longitude lon lng 
        longitudedecimal longitud long decimallongitude decimallong }
      GEOMETRY_POSSIBLE_NAMES   = %w{ geometry the_geom wkb_geometry geom
                                      geojson wkt }
      DEFAULT_SCHEMA            = 'cdb_importer'
      THE_GEOM_WEBMERCATOR     = 'the_geom_webmercator'

      def initialize(db, table_name, schema=DEFAULT_SCHEMA, job=nil)
        @db         = db
        @job        = job || Job.new
        @table_name = table_name
        @schema     = schema
      end #initialize

      def run
        drop_the_geom_webmercator

        create_the_geom_from_geometry_column  || 
        create_the_geom_from_latlon           ||
        create_the_geom_in(table_name)

        raise_if_geometry_collection
        self
      end #run

      def create_the_geom_from_latlon
        latitude_column_name  = latitude_column_name_in(qualified_table_name)
        longitude_column_name = longitude_column_name_in(qualified_table_name)

        return false unless latitude_column_name && longitude_column_name

        job.log 'Creating the_geom from latitude / longitude'
        create_the_geom_in(table_name)
        populate_the_geom_from_latlon(
          qualified_table_name, latitude_column_name, longitude_column_name
        )
      end #create_the_geom_from_latlon

      def create_the_geom_from_geometry_column
        geometry_column_name = geometry_column_in(table_name)
        return false unless geometry_column_name
        column = Column.new(db, table_name, geometry_column_name, schema, job)
        column.geometrify
        
        unless column_exists_in?(table_name, :the_geom)
          column.rename_to(:the_geom) 
        end

        job.log "Creating the_geom from #{geometry_column_name} column"
        handle_multipoint(column) if multipoint?
        self
      rescue => exception
        job.log "Renaming #{geometry_column_name} to invalid_the_geom"
        column.rename_to(:invalid_the_geom) if column
        false
      end #create_the_geom_from_geometry_column

      def populate_the_geom_from_latlon(qualified_table_name, 
      latitude_column_name, longitude_column_name)
        job.log 'Populating the_geom from latitude / longitude'
        db.run(%Q{
          UPDATE #{qualified_table_name} 
          SET the_geom = public.ST_GeomFromText(
              'POINT(' || trim(CAST("#{longitude_column_name}" AS text)) || ' ' ||
                trim(CAST("#{latitude_column_name}" AS text)) || ')', 4326
          )
          WHERE trim(CAST("#{longitude_column_name}" AS text)) ~ 
            '^(([-+]?(([0-9]|[1-9][0-9]|1[0-7][0-9])(\.[0-9]+)?))|[-+]?180)$'
          AND trim(CAST("#{latitude_column_name}" AS text))  ~
            '^(([-+]?(([0-9]|[1-8][0-9])(\.[0-9]+)?))|[-+]?90)$'
        })
      end #populate_the_geom_from_latlon

      def create_the_geom_in(table_name)
        'Creating the_geom column'
        return false if column_exists_in?(table_name, 'the_geom')

        db.run(%Q{
          SELECT public.AddGeometryColumn(
            '#{schema}','#{table_name}','the_geom',4326,'geometry',2
          );
        })
      end #create_the_geom_in

      def column_exists_in?(table_name, column_name)
        columns_in(table_name).include?(column_name.to_sym)
      end #column_exists_in?

      def columns_in(table_name)
        db.schema(table_name, reload: true, schema: schema).map(&:first)
      end #columns_in

      def latitude_column_name_in(qualified_table_name)
        names = LATITUDE_POSSIBLE_NAMES.map { |name| "'#{name}'" }.join(',')
        name  = find_column_in(table_name, names)
        job.log "Identified #{name} as latitude column" if name
        name
      end #latitude_column_name_in

      def longitude_column_name_in(qualified_table_name)
        names = LONGITUDE_POSSIBLE_NAMES.map { |name| "'#{name}'" }.join(',')
        name = find_column_in(table_name, names)
        job.log "Identified #{name} as longitude column" if name
        name
      end #longitude_column_name_in

      def geometry_column_in(qualified_table_name)
        names = GEOMETRY_POSSIBLE_NAMES.map { |name| "'#{name}'" }.join(',')
        find_column_in(table_name, names)
      end #geometry_column_in

      def drop_the_geom_webmercator
        return self unless column_exists_in?(table_name, THE_GEOM_WEBMERCATOR)

        job.log 'Dropping the_geom_webmercator column'
        column = Column.new(db, table_name, THE_GEOM_WEBMERCATOR, schema, job)
        column.drop
      end #drop_the_geom_webmercator

      def raise_if_geometry_collection
        column = Column.new(db, table_name, :the_geom, schema, job)
        return self unless column.geometry_type == 'GEOMETRYCOLLECTION'
        raise GeometryCollectionNotSupportedError
      end #raise_if_geometry_collection

      def find_column_in(table_name, possible_names)
        sample = db[%Q{
          SELECT  column_name 
          FROM    information_schema.columns
          WHERE   table_name ='#{table_name}'
          AND     table_schema = '#{schema}'
          AND     lower(column_name) in (#{possible_names})
          LIMIT   1
        }].first

        !!sample && sample.fetch(:column_name, false)
      end #find_column_in

      def handle_multipoint(column)
        job.log "Renaming the_geom to the_geom_raw"
        column.rename_to(:the_geom_raw)
      end #handle_multipoint

      def multipoint?
        db[%Q{
          SELECT public.GeometryType(the_geom)
          FROM #{qualified_table_name}
          AS geometrytype
        }].first.fetch(:geometrytype) == 'MULTIPOINT'
      rescue
        false
      end #multipoint?

      private

      attr_reader :db, :table_name, :schema, :job

      def qualified_table_name
        "#{schema}.#{table_name}"
      end #qualified_table_name
    end # Georeferencer
  end # Importer2
end # CartoDB

