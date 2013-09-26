# encoding: utf-8
require 'open3'

module CartoDB
  module Importer2
    class Ogr2ogr
      ENCODING  = 'UTF-8'
      SCHEMA    = 'cdb_importer'

      def initialize(table_name, filepath, pg_options, options={})
        self.filepath   = filepath
        self.pg_options = pg_options
        self.table_name = table_name
        self.options    = options
      end #initialize

      def command
        "#{pg_copy_option} #{encoding_option} #{executable_path} "  +
        "#{output_format_option} #{postgres_options} "              +
        "#{projection_option} #{layer_creation_options} "           + 
        "#{filepath} #{track_points_option} #{layer_name_option} "  +
        "#{new_layer_type_option}"
      end #command

      def executable_path
        `which ogr2ogr`.strip
      end #executable_path

      def run(*args)
        stdout, stderr, status  = Open3.capture3(command)
        self.command_output     = stdout + stderr
        self.exit_code          = status.to_i
        self
      end #run

      attr_reader   :exit_code, :command_output

      private

      attr_writer   :exit_code, :command_output
      attr_accessor :filepath, :pg_options, :options, :table_name

      def output_format_option
        "-f PostgreSQL"
      end #output_format_option

      def pg_copy_option
        "PG_USE_COPY=YES"
      end #pg_copy_option

      def encoding_option
        encoding = options.fetch(:encoding, ENCODING)
        "PGCLIENTENCODING=#{encoding} SHAPE_ENCODING=#{encoding}"
      end #encoding_option

      def layer_name_option
        "-nln #{SCHEMA}.#{table_name}"
      end #layer_name_option

      def postgres_options
        %Q{PG:"host=#{pg_options.fetch(:host)} }      +
        %Q{port=#{pg_options.fetch(:port)} }          +
        %Q{user=#{pg_options.fetch(:user)} }          +
        %Q{dbname=#{pg_options.fetch(:database)} }    +
        %Q{password=#{pg_options.fetch(:password)} }  +
        %Q{active_schema=#{SCHEMA}"}
      end #postgres_options

      def layer_creation_options
        "-lco #{dimension_option} -lco #{precision_option}"
      end #layer_creatiopn_options

      def track_points_option
        return "track_points" if filepath =~ /\.gpx/
      end #track_points_option

      def projection_option
        return nil if filepath =~ /\.csv/ || filepath =~ /\.ods/
        "-t_srs EPSG:4326 "
      end #projection_option

      def the_geom_name_option
        "GEOMETRY_NAME=the_geom"
      end #the_geom_name_option

      def dimension_option
        "DIM=2"
      end #dimension_option

      def precision_option
        "PRECISION=NO"
      end #precision_option

      def new_layer_type_option
        "-nlt geometry"
      end #new_layer_type_option

      def append_option
        "-append"
      end #append_option
    end # Ogr2ogr
  end # Importer2
end # CartoDB

