# encoding: utf-8

require 'spec_helper_min'
require 'support/helpers'

describe Carto::Mapcap do
  include Carto::Factories::Visualizations

  before(:all) do
    @user = FactoryGirl.create(:carto_user, private_tables_enabled: true)

    @map, _, _, @visualization = create_full_visualization(@user)
  end

  after(:all) do
    @map.destroy
    @user.destroy
  end

  describe '#ids_vizjson' do
    before(:all) do
      @mapcap = Carto::Mapcap.create!(visualization_id: @visualization.id)
      @ids_json = @mapcap.ids_json
    end

    after(:all) do
      @mapcap.destroy
      @ids_json = nil
    end

    it 'should have visualization_id' do
      @ids_json[:visualization_id].should_not be_nil
    end

    it 'should have map_id' do
      @ids_json[:map_id].should_not be_nil
    end

    it 'should have correct visualization_id' do
      @ids_json[:visualization_id].should eq @visualization.id
    end

    it 'should have correct map_id' do
      @ids_json[:map_id].should eq @map.id
    end

    describe 'with layers' do
      before(:all) do
        @carto_layer = FactoryGirl.create(:carto_layer, kind: 'carto', maps: [@map])
        @visualization.reload

        @mapcap = Carto::Mapcap.create!(visualization_id: @visualization.id)
        @ids_json_layers = @mapcap.ids_json[:layers]
      end

      after(:all) do
        @mapcap.destroy
        @carto_layer.destroy
        @visualization.reload

        @ids_json_layers = nil
      end

      it 'should not have empty layers' do
        @ids_json_layers.should_not be_empty
      end

      it 'should contain layer ids' do
        @ids_json_layers.count.should eq @visualization.layers.count

        @ids_json_layers.each_with_index do |layer, index|
          layer.keys.first.should eq @visualization.layers[index].id
        end
      end
    end
  end

  describe '#populate_ids' do
  end

  describe '#regenerate_visualization' do
  end
end
