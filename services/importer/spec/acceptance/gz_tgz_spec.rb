# encoding: utf-8
require_relative '../../lib/importer/runner'
require_relative '../../lib/importer/job'
require_relative '../../lib/importer/downloader'
require_relative '../factories/pg_connection'
require_relative '../doubles/log'
require_relative '../doubles/user'
require_relative 'acceptance_helpers'
require_relative 'cdb_importer_context'

include CartoDB::Importer2

describe 'gz and tgz regression tests' do
  include AcceptanceHelpers
  include_context "cdb_importer schema"

  before do
    @pg_options  = Factories::PGConnection.new.pg_options
  end

  it 'returns ok with supported gzip file' do
    filepath    = path_to('ok_data.csv.gz')
    downloader  = Downloader.new(filepath)
    runner      = Runner.new({
                               pg: @pg_options,
                               downloader: downloader,
                               log: CartoDB::Importer2::Doubles::Log.new,
                               user: CartoDB::Importer2::Doubles::User.new
                             })
    runner.run
    runner.results.first.success?.should eq true
  end

  it 'returns ok with supported tgz file' do
    filepath    = path_to('ok_data.tgz')
    downloader  = Downloader.new(filepath)
    runner      = Runner.new({
                               pg: @pg_options,
                               downloader: downloader,
                               log: CartoDB::Importer2::Doubles::Log.new,
                               user: CartoDB::Importer2::Doubles::User.new
                             })
    runner.run
    runner.results.first.success?.should eq true
  end

  it 'process one of the two files inside TGZ' do
    filepath    = path_to('ok_and_wrong_data.tgz')
    downloader  = Downloader.new(filepath)
    runner      = Runner.new({
                               pg: @pg_options,
                               downloader: downloader,
                               log: CartoDB::Importer2::Doubles::Log.new,
                               user: CartoDB::Importer2::Doubles::User.new
                             })
    runner.run
    runner.results.first.success?.should eq false
    runner.results.first.error_code.should eq 1002
    runner.results.last.success?.should eq true
    runner.results.last.error_code.nil?.should eq true
  end

  it 'returns error if csv is invalid with supported gzip file' do
    filepath    = path_to('wrong_data.csv.gz')
    downloader  = Downloader.new(filepath)
    runner      = Runner.new({
                               pg: @pg_options,
                               downloader: downloader,
                               log: CartoDB::Importer2::Doubles::Log.new,
                               user: CartoDB::Importer2::Doubles::User.new
                             })
    runner.run
    runner.results.first.success?.should eq false
    runner.results.first.error_code.should eq 1002
  end

  it 'imports GZ file from url' do
      filepath    = "https://raw.githubusercontent.com/CartoDB/cartodb/master/services/importer/spec/fixtures/ok_data.csv.gz"
      downloader  = CartoDB::Importer2::Downloader.new(filepath)
      runner      = CartoDB::Importer2::Runner.new({
                                 pg: @pg_options,
                                 downloader: downloader,
                                 log: CartoDB::Importer2::Doubles::Log.new,
                                 user: CartoDB::Importer2::Doubles::User.new
                               })
      runner.run
      runner.results.first.success?.should eq true
  end

  it 'imports TGZ file from url' do
      filepath    = "https://raw.githubusercontent.com/CartoDB/cartodb/master/services/importer/spec/fixtures/ok_data.tgz"
      downloader  = CartoDB::Importer2::Downloader.new(filepath)
      runner      = CartoDB::Importer2::Runner.new({
                                 pg: @pg_options,
                                 downloader: downloader,
                                 log: CartoDB::Importer2::Doubles::Log.new,
                                 user: CartoDB::Importer2::Doubles::User.new
                               })
      runner.run
      runner.results.first.success?.should eq true
  end
end

