# encoding: utf-8
require 'forwardable'
require_relative './ogr2ogr'
require_relative './csv_normalizer'
require_relative './json2csv'
require_relative './xlsx2csv'
require_relative './georeferencer'

module CartoDB
  module Importer2
    class Loader
      extend Forwardable

      SCHEMA        = 'cdb_importer'
      TABLE_PREFIX  = 'importer'

      def initialize(job, source_file, ogr2ogr=nil, georeferencer=nil)
        self.job            = job
        self.source_file    = source_file
        self.ogr2ogr        = ogr2ogr
        self.georeferencer  = georeferencer
      end #initialize

      def run
        job.log "Using database connection with #{job.concealed_pg_options}"

        CsvNormalizer.new(source_file.fullpath).normalize

        if source_file.extension == '.xlsx'
          xlsx2csv = Xlsx2Csv.new(source_file.fullpath, job)
          xlsx2csv.run
          self.source_file = SourceFile.new(xlsx2csv.converted_filepath)
        end

        if source_file.extension == '.json'
          json2csv = Json2Csv.new(source_file.fullpath, job)
          json2csv.run
          self.source_file = SourceFile.new(json2csv.converted_filepath)
        end

        ogr2ogr.run
        job.log "ogr2ogr output:    #{ogr2ogr.command_output}"
        job.log "ogr2ogr exit code: #{ogr2ogr.exit_code}"

        georeferencer.run
        self
      end #run

      def ogr2ogr
        @ogr2ogr ||= Ogr2ogr.new(job.table_name, fullpath, pg_options)
      end #ogr2ogr

      def georeferencer
        @georeferencer ||= 
          Georeferencer.new(job.db, job.table_name, SCHEMA, job)
      end #georeferencer

      def valid_table_names
        [job.table_name]
      end #valid_table_names

      private

      attr_writer     :ogr2ogr, :georeferencer
      attr_accessor   :job, :source_file

      def_delegators  :job,           :log, :id, :pg_options
      def_delegators  :source_file,   :fullpath, :name, :path
      def_delegators  :ogr2ogr,       :exit_code
    end # Loader
  end # Importer2
end # CartoDB

