# encoding: utf-8
require 'sequel'
require 'rack/test'

shared_examples_for 'synchronization controllers' do
  include Rack::Test::Methods
  include Warden::Test::Helpers
  include CacheHelper

  before(:all) do

    @user = create_user(
      username: 'test',
      email:    'client@example.com',
      password: 'clientex',
      sync_tables_enabled: true
    )
    @api_key = @user.api_key
  end

  before(:each) do
    @db = Rails::Sequel.connection
    Sequel.extension(:pagination)

    CartoDB::Synchronization.repository  = DataRepository::Backend::Sequel.new(@db, :synchronizations)

    delete_user_data @user
    @headers = {
      'CONTENT_TYPE'  => 'application/json',
    }
    host! 'test.localhost.lan'
  end

  after(:all) do
    @user.destroy
  end

  describe 'GET /api/v1/synchronizations' do
    it 'returns a synchronization record' do
      payload = {
        table_name: 'table_1',
        interval:   3600,
        url:        'http://www.foo.com'
      }

      post "/api/v1/synchronizations?api_key=#{@api_key}", payload.to_json, @headers
      id = JSON.parse(last_response.body).fetch('id')

      get "/api/v1/synchronizations/#{id}?api_key=#{@api_key}", nil, @headers
      last_response.status.should == 200

      response = JSON.parse(last_response.body)
      response.fetch('id').should == id
      response.fetch('url').should == payload.fetch(:url)
    end
  end
end
