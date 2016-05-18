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
        types_generating_simple = %w(polygon bubble choropleth category torque torque_cat torque_heat)
        types_generating_simple.each do |type_generating_simple|
          layer = build_layer_with_wizard_properties('type' => type_generating_simple)
          poro_options = Carto::Api::LayerPresenter.new(layer).to_poro['options']
          poro_options['wizard_properties']['type'].should eq type_generating_simple
          style_properties = poro_options['style_properties']
          style_properties['type'].should eq 'simple'
        end
      end
    end

    COLOR = '#fabada'.freeze
    OPACITY = 0.3

    describe 'polygon' do
      describe 'polygon-fill, marker-fill become "color fill" structure' do
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

      describe 'bubble' do
        let(:property) { "actor_foll" }
        let(:qfunction) { "Quantile" }
        let(:radius_min) { 10 }
        let(:radius_max) { 25 }
        let(:bubble_wizard_properties) do
          {
            "type" => "bubble",
            "properties" =>
              {
                "property" => property,
                "qfunction" => qfunction,
                "radius_min" => radius_min,
                "radius_max" => radius_max,
                "marker-fill" => COLOR,
                "marker-opacity" => OPACITY,
                "marker-line-width" => 1,
                "marker-line-color" => "#FFF",
                "marker-line-opacity" => 1,
                "marker-comp-op" => "none",
                "zoom" => 4,
                "geometry_type" => "point",
                "text-placement-type" => "simple",
                "text-label-position-tolerance" => 10
              }
          }
        end

        before(:each) do
          layer = build_layer_with_wizard_properties(bubble_wizard_properties)
          options = Carto::Api::LayerPresenter.new(layer).to_poro['options']
          @fill_color = options['style_properties']['properties']['fill']['color']
        end

        it 'groups radius_min, radius_max into fill color range' do
          expect(@fill_color).to include('range' => [radius_min, radius_max])
        end

        it 'property becomes attribute' do
          expect(@fill_color).to include('attribute' => property)
        end

        it 'bins is set to 10' do
          expect(@fill_color).to include('bins' => 10)
        end

        it 'qfunction becomes quantification' do
          expect(@fill_color).to include('quantification' => qfunction)
        end

        it 'takes fixed color and opacity from marker-*' do
          expect(@fill_color).to include('fixed' => COLOR, 'opacity' => OPACITY)
        end
      end

      describe 'choropleth' do
        let(:property) { "actor_foll" }
        let(:number_of_buckets) { 7 }
        let(:qfunction) { "Quantile" }
        let(:choropleth_wizard_properties) do
          {
            "type" => "choropleth",
            "properties" =>
              {
                "property" => property,
                "method" => "#{number_of_buckets} Buckets",
                "qfunction" => qfunction,
                "color_ramp" => "red",
                "marker-opacity" => OPACITY,
                "marker-width" => 10,
                "marker-allow-overlap" => true,
                "marker-placement" => "point",
                "marker-type" => "ellipse",
                "marker-line-width" => 1,
                "marker-line-color" => "#FFF",
                "marker-line-opacity" => 1,
                "marker-comp-op" => "none",
                "zoom" => 4,
                "geometry_type" => "point"
              }
          }
        end

        before(:each) do
          layer = build_layer_with_wizard_properties(choropleth_wizard_properties)
          options = Carto::Api::LayerPresenter.new(layer).to_poro['options']
          @fill_color = options['style_properties']['properties']['fill']['color']
        end

        it 'transform color ramp  to color array in range' do
          expect(@fill_color).to include('range' => "['#FFEDA0', '#FEB24C', '#F03B20']")
        end

        it 'property becomes attribute' do
          expect(@fill_color).to include('attribute' => property)
        end

        it 'method generates bins' do
          expect(@fill_color).to include('bins' => number_of_buckets)
        end

        it 'qfunction becomes quantification' do
          expect(@fill_color).to include('quantification' => qfunction)
        end

        it 'takes opacity from marker-* or polygon-*' do
          expect(@fill_color).to include('opacity' => OPACITY)
        end
      end

      describe 'labels' do
        describe 'without text-* properties' do
          let(:no_text_wizard_properties) do
            {
              "type" => "choropleth",
              "properties" => { "property" => 'actor_foll' }
            }
          end

          it 'does not generate any label' do
            layer = build_layer_with_wizard_properties(no_text_wizard_properties)
            options = Carto::Api::LayerPresenter.new(layer).to_poro['options']
            options['style_properties']['properties']['labels'].should be_nil
          end
        end

        describe 'with text-* properties' do
          let(:text_name) { "None" }
          let(:text_face_name) { "DejaVu Sans Book" }
          let(:text_size) { 10 }
          let(:text_fill) { "#000" }
          let(:text_halo_radius) { 1 }
          let(:text_halo_fill) { "#ABC" }
          let(:text_dy) { -10 }
          let(:text_allow_overlap) { true }
          let(:text_placement_type) { "simple" }
          let(:text_wizard_properties) do
            {
              "type" => "choropleth",
              "properties" =>
                {
                  "text-name" => text_name,
                  "text-face-name" => text_face_name,
                  "text-size" => text_size,
                  "text-fill" => text_fill,
                  "text-halo-fill" => text_halo_fill,
                  "text-halo-radius" => text_halo_radius,
                  "text-dy" => text_dy,
                  "text-allow-overlap" => text_allow_overlap,
                  "text-placement-type" => text_placement_type,
                  "text-label-position-tolerance" => 10,
                  "text-placement" => "point"
                }
            }
          end

          before(:each) do
            layer = build_layer_with_wizard_properties(text_wizard_properties)
            options = Carto::Api::LayerPresenter.new(layer).to_poro['options']
            @labels = options['style_properties']['properties']['labels']
          end

          it 'generates labels' do
            @labels.should_not be_nil
            @labels['enabled'].should be_true
          end

          it 'text-name generates attribute' do
            expect(@labels).to include('attribute' => text_name)
          end

          it 'text-face-name generates font' do
            expect(@labels).to include('font' => text_face_name)
          end

          it 'text-dy generates offset' do
            expect(@labels).to include('offset' => text_dy)
          end

          it 'text-allow-overlap generates overlap' do
            expect(@labels).to include('overlap' => text_allow_overlap)
          end

          it 'text-placement-type generates placement' do
            expect(@labels).to include('placement' => text_placement_type)
          end

          describe 'fill' do
            before(:each) do
              @labels_fill = @labels['fill']
              @labels_fill.should_not be_nil
              @labels_fill_size = @labels_fill['size']
              @labels_fill_color = @labels_fill['color']
            end

            it 'text-size generates fill size fixed' do
              expect(@labels_fill_size).to include('fixed' => text_size)
            end

            it 'text-fill generates fill color fixed and opacity 1 if not present' do
              expect(@labels_fill_color).to include('fixed' => text_fill, 'opacity' => 1)
            end

            it 'text-fill generates fill color fixed and opacity if present' do
              text_with_opacity = text_wizard_properties
              text_with_opacity["properties"]["text-opacity"] = OPACITY
              layer = build_layer_with_wizard_properties(text_with_opacity)
              options = Carto::Api::LayerPresenter.new(layer).to_poro['options']
              labels_fill_color = options['style_properties']['properties']['labels']['fill']['color']
              expect(labels_fill_color).to include('fixed' => text_fill, 'opacity' => OPACITY)
            end
          end

          describe 'halo' do
            before(:each) do
              @labels_halo = @labels['halo']
              @labels_halo.should_not be_nil
              @labels_halo_size = @labels_halo['size']
              @labels_halo_color = @labels_halo['color']
            end

            it 'text-halo-radius generates halo size fixed' do
              expect(@labels_halo_size).to include('fixed' => text_halo_radius)
            end

            it 'text-halo-fill generates halo color fixed and opacity 1 if not present' do
              expect(@labels_halo_color).to include('fixed' => text_halo_fill, 'opacity' => 1)
            end

            it 'text-halo-fill generates fill color fixed and opacity if present' do
              halo_with_opacity = text_wizard_properties
              halo_with_opacity["properties"]["text-halo-opacity"] = OPACITY
              layer = build_layer_with_wizard_properties(halo_with_opacity)
              options = Carto::Api::LayerPresenter.new(layer).to_poro['options']
              labels_halo_color = options['style_properties']['properties']['labels']['halo']['color']
              expect(labels_halo_color).to include('fixed' => text_halo_fill, 'opacity' => OPACITY)
            end
          end
        end
      end
    end
  end
end
