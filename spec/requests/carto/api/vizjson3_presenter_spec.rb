require 'spec_helper_min'
require 'mock_redis'

describe Carto::Api::VizJSON3Presenter do
  include Carto::Factories::Visualizations
  include_context 'visualization creation helpers'

  before(:all) do
    @user_1 = FactoryGirl.create(:carto_user, private_tables_enabled: false)
  end

  after(:all) do
    @user_1.destroy
  end

  let(:redis_mock) do
    MockRedis.new
  end

  shared_context 'full visualization' do
    before(:all) do
      @map, @table, @table_visualization, @visualization = create_full_visualization(Carto::User.find(@user_1.id))
    end

    after(:all) do
      destroy_full_visualization(@map, @table, @table_visualization, @visualization)
    end

    let(:viewer_user) { @visualization.user }
  end

  describe 'caching' do
    include_context 'full visualization'

    it 'uses the redis vizjson cache' do
      fake_vizjson = { fake: 'sure!', layers: [] }

      cache_mock = mock
      cache_mock.stubs(:cached).with(@visualization.id, false).returns(fake_vizjson).twice
      presenter = Carto::Api::VizJSON3Presenter.new(@visualization, viewer_user, cache_mock)
      v1 = presenter.to_vizjson
      v2 = presenter.to_vizjson
      v1.should eq v2
    end

    it 'is not overriden by v2 caching' do
      v2_presenter = Carto::Api::VizJSONPresenter.new(@visualization, $tables_metadata)
      v3_presenter = Carto::Api::VizJSON3Presenter.new(@visualization, viewer_user)

      v2_vizjson = v2_presenter.to_vizjson
      v3_vizjson = v3_presenter.to_vizjson

      v3_vizjson.should_not eq v2_vizjson
      v2_vizjson[:version].should eq '0.1.0'
      v3_vizjson[:version].should eq '3.0.0'
    end

    it 'does not override v2 caching' do
      v2_presenter = Carto::Api::VizJSONPresenter.new(@visualization, $tables_metadata)
      v3_presenter = Carto::Api::VizJSON3Presenter.new(@visualization, viewer_user)

      v3_vizjson = v3_presenter.to_vizjson
      v2_vizjson = v2_presenter.to_vizjson

      v2_vizjson.should_not eq v3_vizjson
      v2_vizjson[:version].should eq '0.1.0'
      v3_vizjson[:version].should eq '3.0.0'
    end
  end

  describe 'analyses' do
    include_context 'full visualization'

    it 'sends `source` at layer options instead of sql if source is set for named maps' do
      query = "select * from #{@table.name}"

      layer = @visualization.data_layers.first
      layer.options['source'].should eq nil
      layer.options['query'] = query
      layer.save

      # INFO: send :calculate_vizjson won't use cache
      v2_vizjson = Carto::Api::VizJSONPresenter.new(@visualization, $tables_metadata).send :calculate_vizjson
      v3_vizjson = Carto::Api::VizJSON3Presenter.new(@visualization, viewer_user).send :calculate_vizjson

      v2_vizjson[:layers][1][:options][:layer_definition][:layers][0][:options][:sql].should eq query
      v2_vizjson[:layers][1][:options][:layer_definition][:layers][0][:options][:source].should be_nil
      v3_vizjson[:layers][1][:options][:layer_definition][:layers][0][:options][:sql].should eq query
      v3_vizjson[:layers][1][:options][:layer_definition][:layers][0][:options][:source].should be_nil

      source = 'a1'
      layer.options['source'] = source
      layer.save
      @visualization.reload

      v2_vizjson = Carto::Api::VizJSONPresenter.new(@visualization, $tables_metadata).send :calculate_vizjson
      v3_vizjson = Carto::Api::VizJSON3Presenter.new(@visualization, viewer_user).send :calculate_vizjson

      v2_vizjson[:layers][1][:options][:layer_definition][:layers][0][:options][:sql].should be_nil
      v2_vizjson[:layers][1][:options][:layer_definition][:layers][0][:options][:source].should eq source
      v3_vizjson[:layers][1][:options][:layer_definition][:layers][0][:options][:sql].should be_nil
      v3_vizjson[:layers][1][:options][:layer_definition][:layers][0][:options][:source].should eq source
    end
  end

end
