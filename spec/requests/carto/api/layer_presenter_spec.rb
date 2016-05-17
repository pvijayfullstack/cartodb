# encoding: utf-8

require_relative '../../../spec_helper'
require_relative '../../../../app/controllers/carto/api/layer_presenter'
require_relative '../../api/json/layer_presenter_shared_examples'

describe "Carto::Api::LayersController - Layer Model" do
  it_behaves_like 'layer presenters', Carto::Api::LayerPresenter, ::Layer
end

describe "Carto::Api::LayersController - Carto::Layer" do
  it_behaves_like 'layer presenters', Carto::Api::LayerPresenter, Carto::Layer
end

describe Carto::Api::LayerPresenter do
  describe 'wizard_properties migration to style_properties' do
    def wizard_properties(type: 'polygon', properties: {})
      { "type" => type, 'properties' => properties }
    end

    def build_layer_with_wizard_properties(properties)
      FactoryGirl.build(:carto_layer, options: { 'wizard_properties' => properties })
    end

    it "autogenerates `style_properties` based on `wizard_properties` if it isn't present" do
      layer = build_layer_with_wizard_properties(wizard_properties)
      poro_options = Carto::Api::LayerPresenter.new(layer).to_poro['options']
      poro_options['wizard_properties'].should_not be_nil
      style_properties = poro_options['style_properties']
      style_properties.should_not be_nil
      style_properties['autogenerated'].should be_true
    end

    it "doesn't autogenerate `style_properties` if `wizard_properties` is not present or is empty" do
      layer = build_layer_with_wizard_properties(wizard_properties)
      layer.options.delete('wizard_properties')
      poro_options = Carto::Api::LayerPresenter.new(layer).to_poro['options']
      poro_options['wizard_properties'].should be_nil
      style_properties = poro_options['style_properties']
      style_properties.should be_nil

      layer = build_layer_with_wizard_properties(wizard_properties)
      layer.options['wizard_properties'] = nil
      poro_options = Carto::Api::LayerPresenter.new(layer).to_poro['options']
      poro_options['wizard_properties'].should be_nil
      style_properties = poro_options['style_properties']
      style_properties.should be_nil

      layer = build_layer_with_wizard_properties({})
      poro_options = Carto::Api::LayerPresenter.new(layer).to_poro['options']
      poro_options['wizard_properties'].should_not be_nil
      style_properties = poro_options['style_properties']
      style_properties.should be_nil
    end

    it "doesn't autogenerate `style_properties` if type is not mapped" do
      unknown_type = 'wadus'
      layer = build_layer_with_wizard_properties('type' => unknown_type)
      poro_options = Carto::Api::LayerPresenter.new(layer).to_poro['options']
      poro_options['wizard_properties']['type'].should eq unknown_type
      poro_options['style_properties'].should be_nil
    end

    describe 'simple' do
      it 'is generated from several types' do
        types_generating_simple = %w(polygon bubble cloropeth category torque torque_cat torque_heat)
        types_generating_simple.each do |type_generating_simple|
          layer = build_layer_with_wizard_properties('type' => type_generating_simple)
          poro_options = Carto::Api::LayerPresenter.new(layer).to_poro['options']
          poro_options['wizard_properties']['type'].should eq type_generating_simple
          style_properties = poro_options['style_properties']
          style_properties['type'].should eq 'simple'
        end
      end
    end

    describe 'color properties' do
      COLOR = '#fabada'.freeze

      describe 'polygon polygon-fill, marker-fill' do
        describe 'become "color fill" structure' do
          it 'setting opacity 1 if unknown' do
            %w(polygon-fill marker-fill).each do |property|
              properties = { property => COLOR }
              layer = build_layer_with_wizard_properties(wizard_properties(properties: properties))
              options = Carto::Api::LayerPresenter.new(layer).to_poro['options']

              options['wizard_properties']['properties'][property].should eq COLOR

              fill_color = options['style_properties']['properties']['fill']['color']
              fill_color.should eq('fixed' => COLOR, 'opacity' => 1)
            end
          end

          it 'setting related opacity if known' do
            OPACITY = 0.3

            %w(polygon marker).each do |property|
              properties = { "#{property}-fill" => COLOR, "#{property}-opacity" => OPACITY }
              layer = build_layer_with_wizard_properties(wizard_properties(properties: properties))
              options = Carto::Api::LayerPresenter.new(layer).to_poro['options']

              options['wizard_properties']['properties']["#{property}-fill"].should eq COLOR

              fill_color = options['style_properties']['properties']['fill']['color']
              fill_color.should eq('fixed' => COLOR, 'opacity' => OPACITY)
            end
          end
        end
      end
    end
  end
end
