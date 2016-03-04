# encoding: utf-8

require_relative '../../../spec_helper'
require_relative '../../../../app/controllers/api/json/layers_controller'
require_relative 'layers_controller_shared_examples'

describe Api::Json::LayersController do
  it_behaves_like 'layers controllers' do
  end

  include Rack::Test::Methods
  include Warden::Test::Helpers
  include CacheHelper

  include_context 'users helper'

  describe '#create' do
    after(:each) do
      @table_visualization.destroy if @table_visualization
      @table.destroy if @table
      @layer.destroy if @layer
      @visualization.destroy if @visualization
      @map.destroy if @map
    end

    let(:kind) { 'carto' }

    let(:create_layer_url) do
      api_v1_users_layers_create_url(user_domain: @user1.username, user_id: @user1.id, api_key: @user1.api_key)
    end

    def create_map_layer_url(map_id)
      api_v1_maps_layers_create_url(user_domain: @user1.username, map_id: map_id, api_key: @user1.api_key)
    end

    def update_map_layer_url(map_id, layer_id)
      api_v1_maps_layers_update_url(
        user_domain: @user1.username,
        map_id: map_id,
        id: layer_id,
        api_key: @user1.api_key)
    end

    def create_full_visualization(map: FactoryGirl.create(:carto_map, user_id: @user1.id))
      @map = map
      @table = FactoryGirl.create(:carto_user_table, user_id: @user1.id, map_id: @map.id)
      @table_visualization = FactoryGirl.create(
        :carto_visualization,
        user: @carto_user1, type: 'table', name: @table.name, map_id: @table.map_id)
      @visualization = FactoryGirl.create(:carto_visualization, user_id: @user1.id, map: @map)
      # Need to mock the nonexistant table because factories use Carto::* models
      CartoDB::Visualization::Member.any_instance.stubs(:propagate_name_to).returns(true)
      CartoDB::Visualization::Member.any_instance.stubs(:propagate_privacy_to).returns(true)
    end

    let(:layer_json) do
      { kind: kind, options: { 'table_name' => nil, 'user_name' => nil }, order: 1, infowindow: {}, tooltip: {} }
    end

    it 'creates layers' do
      post_json create_layer_url, layer_json do |response|
        response.status.should eq 200
        layer_response = response.body

        layer_response.delete(:id).should_not be_nil
        layer_response.should eq layer_json
      end
    end

    it 'creates layers on maps' do
      create_full_visualization

      post_json create_map_layer_url(@map.id), layer_json.merge(options: { table_name: @table.name }) do |response|
        response.status.should eq 200
        layer_response = response.body

        layer_id = layer_response.delete(:id)
        layer_id.should_not be_nil

        layer_options = layer_response.delete(:options)
        layer_options.should eq ({ "table_name" => @table.name })

        layer_response.should eq (layer_json.except(:options))

        @layer = Carto::Layer.find(layer_id)
        @layer.maps.map(&:id).first.should eq @map.id
      end
    end

    it 'updates layers' do
      map = FactoryGirl.create(:carto_map_with_layers, user_id: @user1.id)
      create_full_visualization(map: map)
      @layer = map.layers.first

      new_order = 2
      new_layer_json = layer_json.merge(
        options: { 'random' => '1' },
        order: new_order
      )
      put_json update_map_layer_url(map.id, @layer.id), new_layer_json do |response|
        response.status.should eq 200
        layer_response = response.body

        layer_response.delete(:id).should eq @layer.id
        layer_response.delete(:options).should eq new_layer_json[:options]
        layer_response.delete(:order).should eq new_order
      end
    end

    it 'does not update table_name or users_name options' do
      map = FactoryGirl.create(:carto_map_with_layers, user_id: @user1.id)
      create_full_visualization(map: map)
      @layer = map.layers.first

      new_layer_json = layer_json.merge(
        options: { 'table_name' => 'other_table_name', 'user_name' => 'other_username' }
      )
      put_json update_map_layer_url(map.id, @layer.id), new_layer_json do |response|
        response.status.should eq 200
        layer_response = response.body

        layer_response.delete(:options).should eq layer_json[:options]
      end
    end
  end
end
