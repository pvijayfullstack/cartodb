# encoding: utf-8
require_relative '../lib/table_geocoder.rb'
require_relative '../../geocoder/lib/geocoder.rb'
require_relative 'factories/pg_connection'
require 'ruby-debug'

RSpec.configure do |config|
  config.mock_with :mocha
end

describe CartoDB::TableGeocoder do
  let(:default_params) { {app_id: '', token: '', mailto: ''} }
  before do
    conn          = CartoDB::Importer2::Factories::PGConnection.new
    @db           = conn.connection
    @pg_options   = conn.pg_options
    @table_name   = "ne_10m_populated_places_simple"
    load_sql path_to("populated_places_short.sql"), @pg_options
  end

  after do
    @db.drop_table @table_name
  end

  describe '#run' do
    before do
      @tg = CartoDB::TableGeocoder.new(default_params.merge({
        table_name: @table_name,
        formatter:  "name, ', ', sov0name",
        connection: @db
      }))
      @tg.geocoder.stubs(:upload).returns(true)
      @tg.geocoder.stubs(:request_id).returns('111')
      @tg.run
    end

    it "generates a csv file for uploading" do
      File.open("#{@tg.working_dir}/wadus.csv").read.should == File.read(path_to('nokia_input.csv'))
    end

    it "assigns a remote_id" do
      @tg.remote_id.should == '111'
    end
  end

  describe '#generate_csv' do
    before do
      @tg = CartoDB::TableGeocoder.new(default_params.merge({
        table_name: @table_name,
        formatter:  "name, ', ', sov0name",
        connection: @db
      }))
      @tg.add_georef_status_column
    end

    it "generates a csv file with the correct format" do
      @tg.generate_csv
      File.open("#{@tg.working_dir}/wadus.csv").read.should == File.read(path_to('nokia_input.csv'))
    end

    it "honors max_rows" do
      @tg.stubs(:max_rows).returns 10
      @tg.generate_csv
      `wc -l #{@tg.working_dir}/wadus.csv `.split.first.to_i.should eq 11
    end
  end

  describe '#download_results' do
    it 'gets the geocoder results' do
      tg = CartoDB::TableGeocoder.new(table_name: 'a', connection: 'b')
      tg.geocoder.expects(:result).times(1).returns('a')
      tg.download_results
      tg.result.should == 'a'
    end
  end

  describe '#deflate_results' do
    it 'raises an error if no results file' do
      dir = Dir.mktmpdir
      tg = CartoDB::TableGeocoder.new(table_name: 'a', connection: 'b', working_dir: dir)
      expect { tg.deflate_results }.to raise_error
    end

    it 'extracts nokia result files' do
      dir = Dir.mktmpdir
      `cp #{path_to('kXYkQhuDfxnUSmWFP3dmq6TzTZAzwy4x.zip')} #{dir}`
      tg = CartoDB::TableGeocoder.new(table_name: 'a', connection: 'b', working_dir: dir)
      tg.deflate_results
      filename = 'result_20130919-04-55_6.2.46.1_out.txt'
      destfile = File.open(File.join(dir, filename))
      destfile.read.should eq File.open(path_to(filename)).read
    end
  end

  describe '#create_temp_table' do
    it 'raises error if no remote_id' do
      tg = CartoDB::TableGeocoder.new(table_name: 'a', connection: @db)
      expect { tg.create_temp_table }.to raise_error(Sequel::DatabaseError)
    end

    it 'creates a temporary table' do
      tg = CartoDB::TableGeocoder.new(table_name: 'a', connection: @db, remote_id: 'geo_HvyxzttLyFhaQ7JKmnrZxdCVySd8N0Ua', schema: 'public')
      tg.drop_temp_table
      tg.create_temp_table
      @db.fetch("select * from #{tg.temp_table_name}").all.should eq []
    end
  end

  describe '#temp_table_name' do
    it 'returns geo_remote_id if available' do
      tg = CartoDB::TableGeocoder.new(table_name: 'a', connection: @db, remote_id: 'doesnotexist')
      tg.temp_table_name.should eq 'cdb.geo_doesnotexist'
    end

    it 'returns an alternative name if the table exists' do
      tg = CartoDB::TableGeocoder.new(table_name: 'a', connection: @db, remote_id: 'wadus', schema: 'public')      
      @db.run("drop table if exists geo_wadus; create table geo_wadus (id int)")
      @db.run("drop table if exists geo_wadus_1; create table geo_wadus_1 (id int)")
      tg.temp_table_name.should eq 'public.geo_wadus'
    end
  end

  describe '#import_results_to_temp_table' do
    after do
      @db.drop_table('geo_temp_table')
    end
    
    it 'loads the Nokia output format to an existing temp table' do
      tg = CartoDB::TableGeocoder.new(table_name: 'a', connection: @db, remote_id: 'temp_table', schema: 'public')      
      tg.create_temp_table
      tg.stubs(:deflated_results_path).returns(path_to('nokia_output.txt'))
      tg.import_results_to_temp_table
      @db.fetch(%Q{
        SELECT count(*) FROM #{tg.temp_table_name} 
        WHERE displayLatitude IS NOT NULL AND displayLongitude IS NOT NULL
      }).first[:count].should eq 44
    end
  end

  describe '#load_results_into_original_table' do
  end

  describe '#add_georef_status_column' do
    before do
      @db.run("create table wwwwww (id integer)")
      @tg = CartoDB::TableGeocoder.new(table_name: 'wwwwww', connection: @db, remote_id: 'wadus')
    end

    after do
      @db.run("drop table wwwwww")
    end

    it 'adds a boolean cartodb_georef_status column' do
      @tg.add_georef_status_column
      @db.run("select cartodb_georef_status from wwwwww").should eq nil
    end

    it 'does nothing when the column already exists' do
      @tg.expects(:cast_georef_status_column).once
      @tg.add_georef_status_column
      @tg.add_georef_status_column
    end

    it 'casts cartodb_georef_status to boolean if needed' do
      @db.run('alter table wwwwww add column cartodb_georef_status text')
      @tg.add_georef_status_column
      @db.fetch("select data_type from information_schema.columns where table_name = 'wwwwww'")
        .first[:data_type].should eq 'boolean'
    end
  end

  # it "Geocodes a table" do
  #   t = CartoDB::TableGeocoder.new(
  #     table_name: @table_name,
  #     formatter:  "name, ', ', sov0name",
  #     connection: @db,
  #     app_id: 'KuYppsdXZznpffJsKT24',
  #     token:  'A7tBPacePg9Mj_zghvKt9Q',
  #     mailto: 'arango@gmail.com',
  #     schema: 'public'
  #   )
  #   @db.fetch("select count(*) from #{@table_name} where the_geom is null").first[:count].should eq 37
  #   t.run
  #   `open #{t.working_dir}`
  #   until t.geocoder.status == 'completed' do
  #     t.geocoder.update_status
  #     puts "#{t.geocoder.status} #{t.geocoder.processed_rows}/#{t.geocoder.total_rows}"
  #     sleep(2)
  #   end
  #   t.process_results
  #   t.geocoder.status.should eq 'completed'
  #   @db.fetch("select count(*) from #{@table_name} where the_geom is null").first[:count].should eq 4
  #   @db.fetch("select count(*) from #{@table_name} where cartodb_georef_status is false").first[:count].should eq 4
  # end


  def path_to(filepath = '')
    File.expand_path(
      File.join(File.dirname(__FILE__), "../spec/fixtures/#{filepath}")
    )
  end #path_to


  def load_sql(path, pg_options)
    `psql -U #{pg_options[:user]} -f #{path} #{pg_options[:database]}`
  end # create_table

end # CartoDB::Geocoder
