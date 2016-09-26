require 'spec_helper_min'
require 'support/helpers'

describe Carto::Api::ConnectorsController do
  include HelperMethods
  include_context 'organization with users helper'

  before(:all) do
    FactoryGirl.create(:carto_feature_flag, name: 'carto-connectors', restricted: false)
    @user = FactoryGirl.create(:carto_user)
    @connector_provider_postgres = FactoryGirl.create(:connector_provider, name: 'postgres')
    @connector_provider_hive = FactoryGirl.create(:connector_provider, name: 'hive')
    @connector_config_user = FactoryGirl.create(:connector_configuration,
                                                  user_id: @user.id,
                                                  connector_provider_id: @connector_provider_postgres.id,
                                                  enabled: true,
                                                  max_rows: 100)
    @connector_config_org_user = FactoryGirl.create(:connector_configuration,
                                                      user_id: @org_user_1.id,
                                                      connector_provider_id: @connector_provider_hive.id,
                                                      enabled: false,
                                                      max_rows: 100)
    @connector_config_org = FactoryGirl.create(:connector_configuration,
                                                 organization_id: @organization.id,
                                                 connector_provider_id: @connector_provider_hive.id,
                                                 enabled: true,
                                                 max_rows: 100)
  end

  after(:all) do
    Carto::FeatureFlag.destroy_all
    @user.destroy
    @connector_config_user.destroy
    @connector_config_org_user.destroy
    @connector_config_org.destroy
    @connector_provider.destroy
    @connector_provider_org.destroy
  end

  describe '#index' do
    it 'returns provider enabled for regular user' do
      get_json api_v1_connectors_index_url(user_domain: @user.username, api_key: @user.api_key), {}, @headers do |response|
        response.status.should be_success
        response.body[:postgres][:name].should eq "PostgreSQL"
        response.body[:postgres][:enabled].should eq true
      end
    end

    it 'returns provider false for organization user' do
      get_json api_v1_connectors_index_url(user_domain: @org_user_1.username,
                                           api_key: @org_user_1.api_key), {}, @headers do |response|
        response.status.should be_success
        response.body[:hive][:name].should eq "Hive"
        response.body[:hive][:enabled].should eq false
      end
    end

    it 'returns provider true for organization' do
      get_json api_v1_connectors_index_url(user_domain: @org_user_2.username,
                                           api_key: @org_user_2.api_key), {}, @headers do |response|
        response.status.should be_success
        response.body[:hive][:name].should eq "Hive"
        response.body[:hive][:enabled].should eq true
      end
    end
  end
end
