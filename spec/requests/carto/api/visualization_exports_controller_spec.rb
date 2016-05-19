# encoding: utf-8
require 'spec_helper_min'
require_dependency 'carto/uuidhelper'
require 'factories/carto_visualizations'
require 'support/helpers'

describe Carto::Api::VisualizationExportsController do
  include Carto::UUIDHelper
  include Carto::Factories::Visualizations
  include HelperMethods

  before(:all) do
    @user = FactoryGirl.create(:carto_user, private_maps_enabled: true)
    @user2 = FactoryGirl.create(:carto_user, private_maps_enabled: true)
  end

  after(:all) do
    # This avoids connection leaking.
    ::User[@user.id].destroy
    ::User[@user2.id].destroy
  end

  describe '#create' do

    before(:each) do
      bypass_named_maps
      @map, @table, @table_visualization, @visualization = create_full_visualization(@user)
      carto_layer = @visualization.layers.find { |l| l.kind == 'carto' }
      carto_layer.options[:user_name] = @user.username
      carto_layer.save
    end

    after(:each) do
      destroy_full_visualization(@map, @table, @table_visualization, @visualization)
    end

    def create_visualization_export_url(user = nil)
      visualization_exports_url(user_domain: user ? user.username : nil, api_key: user ? user.api_key : nil)
    end

    it 'returns 404 for nonexisting visualizations' do
      post_json create_visualization_export_url(@user), visualization_id: random_uuid do |response|
        response.status.should eq 404
      end
    end

    it 'returns 403 for non accessible visualizations' do
      @visualization.privacy = Carto::Visualization::PRIVACY_PRIVATE
      @visualization.save

      post_json create_visualization_export_url(@user2), visualization_id: @visualization.id do |response|
        response.status.should eq 403
      end
    end

    it 'returns 403 for non accessible visualizations (private and protected) for anonymous users' do
      @visualization.privacy = Carto::Visualization::PRIVACY_PRIVATE
      @visualization.save

      post_json create_visualization_export_url, visualization_id: @visualization.id do |response|
        response.status.should eq 403
      end

      @visualization.privacy = Carto::Visualization::PRIVACY_PROTECTED
      @visualization.save

      post_json create_visualization_export_url, visualization_id: @visualization.id do |response|
        response.status.should eq 403
      end
    end

    it 'returns 422 if user_tables_ids param contains user table ids not related to the visualization' do
      post_json create_visualization_export_url(@user),
                visualization_id: @visualization.id, user_tables_ids: random_uuid do |response|
        response.status.should eq 422
      end
    end

    it 'returns 422 if visualization type is `table`' do
      @visualization.update_attributes(type: Carto::Visualization::TYPE_CANONICAL)
      post_json create_visualization_export_url(@user), visualization_id: @visualization.id do |response|
        response.status.should eq 422
        response.body[:errors].should match(/Only derived visualizations can be exported/)
      end
    end

    it 'enqueues a job and returns the id' do
      Resque.expects(:enqueue).with(Resque::ExporterJobs, anything).once
      post_json create_visualization_export_url(@user), visualization_id: @visualization.id do |response|
        response.status.should eq 201
        visualization_export_id = response.body[:id]
        visualization_export_id.should_not be_nil
        visualization_export = Carto::VisualizationExport.find(visualization_export_id)
        visualization_export.visualization_id.should eq @visualization.id
        visualization_export.user_id.should eq @user.id
        visualization_export.state.should eq Carto::VisualizationExport::STATE_PENDING
      end
    end

    it 'enqueues a job and returns the id for anonymous, valid exports' do
      @visualization.privacy = Carto::Visualization::PRIVACY_LINK
      @visualization.save

      Resque.expects(:enqueue).with(Resque::ExporterJobs, anything).once
      post_json create_visualization_export_url, visualization_id: @visualization.id do |response|
        response.status.should eq 201
        visualization_export_id = response.body[:id]
        visualization_export_id.should_not be_nil
        visualization_export = Carto::VisualizationExport.find(visualization_export_id)
        visualization_export.visualization_id.should eq @visualization.id
        visualization_export.user_id.should be_nil
        visualization_export.state.should eq Carto::VisualizationExport::STATE_PENDING
      end
    end
  end

  describe '#show' do
    before(:all) do
      @visualization = FactoryGirl.create(:carto_visualization, user: @user)
      @export = FactoryGirl.create(:visualization_export, visualization: @visualization, user: @user)
      @anonymous_export = FactoryGirl.create(:visualization_export, visualization: @visualization, user: nil)
    end

    after(:all) do
      @export.destroy
      @visualization.destroy
    end

    def export_url(visualization_export_id, user = nil)
      visualization_export_url(
        user_domain: user ? user.username : nil,
        api_key: user ? user.api_key : nil,
        id: visualization_export_id
      )
    end

    it 'returns 404 for nonexisting exports' do
      get_json export_url(random_uuid, @user) do |response|
        response.status.should eq 404
      end
    end

    it 'returns 403 for exports from other user' do
      get_json export_url(@export.id, @user2) do |response|
        response.status.should eq 403
      end
    end

    it 'returns the visualization export' do
      get_json export_url(@export.id, @user) do |response|
        response.status.should eq 200
        visualization_export = response.body
        visualization_export[:id].should eq @export.id
        visualization_export[:visualization_id].should eq @export.visualization_id
        visualization_export[:user_id].should eq @user.id
        visualization_export[:state].should eq @export.state
      end
    end

    it 'returns the visualization export for anonymous exports' do
      get_json export_url(@anonymous_export.id) do |response|
        response.status.should eq 200
        visualization_export = response.body
        visualization_export[:id].should eq @anonymous_export.id
        visualization_export[:user_id].should be_nil
      end
    end
  end
end
