# encoding: utf-8
require_relative '../../lib/importer/runner'
require_relative '../../lib/importer/job'
require_relative '../../lib/importer/downloader'
require_relative '../factories/pg_connection'
require_relative '../doubles/log'

include CartoDB::Importer2

describe 'csv regression tests' do
  before do
    pg_connection = Factories::PGConnection.new
    @db = pg_connection.connection
    @pg_options  = pg_connection.pg_options
    @db.execute('CREATE SCHEMA IF NOT EXISTS cdb_importer')
  end

  after(:each) do
    @db.execute('DROP SCHEMA cdb_importer CASCADE')
    @db.disconnect
  end

  it 'georeferences files with lat / lon columns' do
    filepath    = path_to('../../../../spec/support/data/csv_with_lat_lon.csv')
    downloader  = Downloader.new(filepath)
    runner      = Runner.new(@pg_options, downloader, Doubles::Log.new)
    runner.run

    result = runner.results.first
    result.success?.should be_true, "error code: #{result.error_code}, trace: #{result.log_trace}"
    geometry_type_for(runner).should eq 'POINT'
  end

  it 'imports XLS files' do
    #TODO: changed 'skipped' for a simple ngos.xlsx import, but should be improved for some file with geometry import data
    filepath    = path_to('../../../../spec/support/data/ngos.xlsx')
    downloader  = Downloader.new(filepath)
    runner      = Runner.new(@pg_options, downloader, Doubles::Log.new)
    runner.run

    result = runner.results.first
    result.success?.should be_true, "error code: #{result.error_code}, trace: #{result.log_trace}"
  end

  it 'imports files exported from the SQL API' do
    filepath    = path_to('ne_10m_populated_places_simple.csv')
    downloader  = Downloader.new(filepath)
    runner      = Runner.new(@pg_options, downloader, Doubles::Log.new)
    runner.run

    geometry_type_for(runner).should eq 'POINT'
  end

  it 'imports files from Google Fusion Tables' do
    url = "https://www.google.com/fusiontables/exporttable" +
          "?query=select+*+from+1dimNIKKwROG1yTvJ6JlMm4-B4LxMs2YbncM4p9g"
    downloader  = Downloader.new(url)
    runner      = Runner.new(@pg_options, downloader, Doubles::Log.new)
    runner.run

    geometry_type_for(runner).should eq 'POINT'
  end

  it 'imports files with a the_geom column in GeoJSON' do
    filepath    = path_to('csv_with_geojson.csv')
    downloader  = Downloader.new(filepath)
    runner      = Runner.new(@pg_options, downloader, Doubles::Log.new)
    runner.run

    geometry_type_for(runner).should eq 'MULTIPOLYGON'
  end

  it 'imports files with spaces as delimiters' do
    filepath    = path_to('fsq_places_uniq.csv')
  end

  it 'imports files with & in the name' do
    filepath    = path_to('ne_10m_populated_places_&simple.csv')
    downloader  = Downloader.new(filepath)
    runner      = Runner.new(@pg_options, downloader, Doubles::Log.new)
    runner.run

    geometry_type_for(runner).should eq 'POINT'
  end

  it 'imports records with cell line breaks' do
    filepath    = path_to('in_cell_line_breaks.csv')
    downloader  = Downloader.new(filepath)
    runner      = Runner.new(@pg_options, downloader, Doubles::Log.new)
    runner.run

    result = runner.results.first
    runner.db[%Q{
      SELECT count(*)
      FROM #{result.schema}.#{result.table_name}
      AS count
    }].first.fetch(:count).should eq 7
  end

  def path_to(filepath)
    File.join(File.dirname(__FILE__), "../fixtures/#{filepath}")
  end #path_to

  def geometry_type_for(runner)
    result      = runner.results.first
    table_name  = result.tables.first
    schema      = result.schema

    runner.db[%Q{
      SELECT public.GeometryType(the_geom)
      FROM "#{schema}"."#{table_name}"
    }].first.fetch(:geometrytype)
  end #geometry_type_for

  def sample_for(job)
    job.db[%Q{
      SELECT *
      FROM #{job.qualified_table_name}
    }].first
  end #sample_for
end # csv regression tests

