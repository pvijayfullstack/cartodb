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
  def presenter_with_style_properties(layer)
    Carto::Api::LayerPresenter.new(layer, with_style_properties: true)
  end

  describe 'wizard_properties migration to style_properties' do
    def wizard_properties(type: 'polygon', properties: {})
      { "type" => type, 'properties' => properties }
    end

    def build_layer_with_wizard_properties(properties)
      FactoryGirl.build(:carto_layer, options: { 'wizard_properties' => properties })
    end

    it "doesn't autogenerate `style_properties` if `wizard_properties` isn't present but it's not requested" do
      layer = build_layer_with_wizard_properties(wizard_properties)
      poro_options = Carto::Api::LayerPresenter.new(layer).to_poro['options']
      poro_options['wizard_properties'].should_not be_nil
      poro_options['style_properties'].should be_nil
    end

    it "autogenerates `style_properties` based on `wizard_properties` if it isn't present and it's requested" do
      layer = build_layer_with_wizard_properties(wizard_properties)
      poro_options = presenter_with_style_properties(layer).to_poro['options']
      poro_options['wizard_properties'].should_not be_nil
      style_properties = poro_options['style_properties']
      style_properties.should_not be_nil
      style_properties['autogenerated'].should be_true
    end

    it "autogenerates `style_properties` based on `wizard_properties` if it is present but autogenerated" do
      layer = build_layer_with_wizard_properties(wizard_properties)
      layer.options['style_properties'] = { 'autogenerated' => true, 'wadus' => 'wadus' }
      poro_options = presenter_with_style_properties(layer).to_poro['options']
      poro_options['wizard_properties'].should_not be_nil
      style_properties = poro_options['style_properties']
      style_properties.should_not be_nil
      style_properties['autogenerated'].should be_true
      style_properties['type'].should_not be_nil
      style_properties['wadus'].should be_nil
    end

    it "doesn't autogenerate `style_properties` based on `wizard_properties` if it is present and not autogenerated" do
      layer = build_layer_with_wizard_properties(wizard_properties)
      layer.options['style_properties'] = { 'autogenerated' => false, 'wadus' => 'wadus' }
      poro_options = presenter_with_style_properties(layer).to_poro['options']
      poro_options['wizard_properties'].should_not be_nil
      style_properties = poro_options['style_properties']
      style_properties.should_not be_nil
      style_properties['autogenerated'].should be_false
      style_properties['wadus'].should eq 'wadus'
    end

    it "doesn't autogenerate `style_properties` if `wizard_properties` is not present or is empty" do
      layer = build_layer_with_wizard_properties(wizard_properties)
      layer.options.delete('wizard_properties')
      poro_options = presenter_with_style_properties(layer).to_poro['options']
      poro_options['wizard_properties'].should be_nil
      style_properties = poro_options['style_properties']
      style_properties.should be_nil

      layer = build_layer_with_wizard_properties(wizard_properties)
      layer.options['wizard_properties'] = nil
      poro_options = presenter_with_style_properties(layer).to_poro['options']
      poro_options['wizard_properties'].should be_nil
      style_properties = poro_options['style_properties']
      style_properties.should be_nil

      layer = build_layer_with_wizard_properties({})
      poro_options = presenter_with_style_properties(layer).to_poro['options']
      poro_options['wizard_properties'].should_not be_nil
      style_properties = poro_options['style_properties']
      style_properties.should be_nil
    end

    it "doesn't autogenerate `style_properties` if type is not mapped" do
      unknown_type = 'wadus'
      layer = build_layer_with_wizard_properties('type' => unknown_type)
      poro_options = presenter_with_style_properties(layer).to_poro['options']
      poro_options['wizard_properties']['type'].should eq unknown_type
      poro_options['style_properties'].should be_nil
    end

    describe 'options migration' do
      it 'migrates tile_style_custom to cartocss_custom (defaults to false)' do
        layer = build_layer_with_wizard_properties(wizard_properties(properties: {}))
        layer.options.delete('tile_style_custom')
        presenter_with_style_properties(layer).to_poro['options']['cartocss_custom'].should eq false
        layer.options['tile_style_custom'] = true
        presenter_with_style_properties(layer).to_poro['options']['cartocss_custom'].should eq true
        layer.options['tile_style_custom'] = false
        presenter_with_style_properties(layer).to_poro['options']['cartocss_custom'].should eq false
      end

      it 'migrates tile_style_history to cartocss_history (defaults to [])' do
        layer = build_layer_with_wizard_properties(wizard_properties(properties: {}))
        layer.options.delete('tile_style_history')
        presenter_with_style_properties(layer).to_poro['options']['cartocss_history'].should eq []
        layer.options['tile_style_history'] = ['wadus', 'wadus2']
        presenter_with_style_properties(layer).to_poro['options']['cartocss_history'].should eq ['wadus', 'wadus2']
        layer.options['tile_style_history'] = []
        presenter_with_style_properties(layer).to_poro['options']['cartocss_history'].should eq []
      end
    end

    describe 'simple' do
      it 'is generated from several types' do
        types_generating_simple = %w(polygon bubble choropleth category torque torque_cat)
        types_generating_simple.each do |type_generating_simple|
          layer = build_layer_with_wizard_properties('type' => type_generating_simple)
          poro_options = presenter_with_style_properties(layer).to_poro['options']
          poro_options['wizard_properties']['type'].should eq type_generating_simple
          style_properties = poro_options['style_properties']
          style_properties['type'].should eq 'simple'
        end
      end

      it 'has defaults for animated' do
        layer = build_layer_with_wizard_properties(wizard_properties(properties: {}))
        poro_options = presenter_with_style_properties(layer).to_poro['options']
        animated = poro_options['style_properties']['properties']['animated']
        animated.should_not be_nil

        animated['enabled'].should eq false
        animated['attribute'].should be_nil
        animated['overlap'].should eq false
        animated['duration'].should eq 30
        animated['steps'].should eq 256
        animated['resolution'].should eq 2
        animated['trails'].should eq 2
      end

      it 'has defaults for labels' do
        layer = build_layer_with_wizard_properties(wizard_properties(properties: {}))
        poro_options = presenter_with_style_properties(layer).to_poro['options']
        labels = poro_options['style_properties']['properties']['labels']
        labels.should_not be_nil

        labels['enabled'].should eq false
        labels['attribute'].should be_nil
        labels['font'].should eq 'DejaVu Sans Book'
        fill = labels['fill']
        fill['size']['fixed'].should eq 10
        fill_color = fill['color']
        fill_color['fixed'].should eq '#000'
        fill_color['opacity'].should eq 1
        halo = labels['halo']
        halo['size']['fixed'].should eq 1
        halo_color = halo['color']
        halo_color['fixed'].should eq '#111'
        halo_color['opacity'].should eq 1
        labels['offset'].should eq(-10)
        labels['overlap'].should eq true
        labels['placement'].should eq 'point'
      end

      it 'defaults missing labels attributes' do
        properties = {
          "text-face-name" => "whatever"
        }
        layer = build_layer_with_wizard_properties(wizard_properties(properties: properties))
        poro_options = presenter_with_style_properties(layer).to_poro['options']
        labels = poro_options['style_properties']['properties']['labels']
        labels.should_not be_nil

        labels['enabled'].should eq true
        labels['font'].should eq 'whatever'

        labels['attribute'].should be_nil
        fill = labels['fill']
        fill['size']['fixed'].should eq 10
        fill_color = fill['color']
        fill_color['fixed'].should eq '#000'
        fill_color['opacity'].should eq 1
        halo = labels['halo']
        halo['size']['fixed'].should eq 1
        halo_color = halo['color']
        halo_color['fixed'].should eq '#111'
        halo_color['opacity'].should eq 1
        labels['offset'].should eq(-10)
        labels['overlap'].should eq true
        labels['placement'].should eq 'point'
      end
    end

    describe 'wizard migration' do
      COLOR = '#fabada'.freeze
      COLOR_1 = "#FACADA".freeze
      COLOR_2 = "#TACADA".freeze
      OPACITY = 0.3

      describe 'polygon' do
        describe 'polygon-fill, marker-fill become "color fill" structure' do
          it 'setting opacity 1 if unknown' do
            %w(polygon-fill marker-fill).each do |property|
              properties = { property => COLOR }
              layer = build_layer_with_wizard_properties(wizard_properties(properties: properties))
              options = presenter_with_style_properties(layer).to_poro['options']

              options['wizard_properties']['properties'][property].should eq COLOR

              fill_color = options['style_properties']['properties']['fill']['color']
              fill_color.should eq('fixed' => COLOR, 'opacity' => 1)
            end
          end

          it 'setting related opacity if known' do
            %w(polygon marker).each do |property|
              properties = { "#{property}-fill" => COLOR, "#{property}-opacity" => OPACITY }
              layer = build_layer_with_wizard_properties(wizard_properties(properties: properties))
              options = presenter_with_style_properties(layer).to_poro['options']

              options['wizard_properties']['properties']["#{property}-fill"].should eq COLOR

              fill_color = options['style_properties']['properties']['fill']['color']
              fill_color.should eq('fixed' => COLOR, 'opacity' => OPACITY)
            end
          end
        end
      end

      describe 'cluster' do
        let(:query_wrapper) { "with meta ... <%= sql %> ..." }
        before(:each) do
          properties = { "type" => "cluster", "properties" => { "method" => "3 Buckets", "marker-fill" => "#FD8D3C" } }
          options = { 'query_wrapper' => query_wrapper, 'wizard_properties' => properties }
          layer = FactoryGirl.build(:carto_layer, options: options)
          @options = presenter_with_style_properties(layer).to_poro['options']
          @properties = @options['style_properties']['properties']
        end

        it 'sets type simple and cartocss_custom to true' do
          @options['style_properties']['type'].should eq 'simple'
          @options['cartocss_custom'].should eq true
        end

        it 'sets query_wrapper at sql_wrap' do
          @options['sql_wrap'].should eq query_wrapper
        end
      end

      describe 'bubble' do
        let(:property) { "actor_foll" }
        let(:qfunction) { "Quantile" }
        let(:radius_min) { 10 }
        let(:radius_max) { 25 }
        let(:marker_comp_op) { "multiply" }
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
                "zoom" => 4,
                "geometry_type" => "point",
                "text-placement-type" => "simple",
                "text-label-position-tolerance" => 10,
                "marker-comp-op" => marker_comp_op
              }
          }
        end

        before(:each) do
          layer = build_layer_with_wizard_properties(bubble_wizard_properties)
          options = presenter_with_style_properties(layer).to_poro['options']
          @properties = options['style_properties']['properties']
          @fill_color = @properties['fill']['color']
          @fill_size = @properties['fill']['size']
        end

        it 'marker-comp-op becomes blending' do
          expect(@properties).to include('blending' => marker_comp_op)
        end

        describe 'fill size' do
          it 'groups radius_min, radius_max into fill size range' do
            expect(@fill_size).to include('range' => [radius_min, radius_max])
          end

          it 'property becomes attribute' do
            expect(@fill_size).to include('attribute' => property)
          end

          it 'bins is set to 10' do
            expect(@fill_size).to include('bins' => 10)
          end

          it 'qfunction becomes quantification' do
            expect(@fill_size).to include('quantification' => qfunction)
          end

          it 'include animated disabled' do
            expect(@properties['animated']['enabled']).to be_false
          end
        end

        describe 'fill color' do
          it 'takes fixed color and opacity from marker-*' do
            expect(@fill_color).to include('fixed' => COLOR, 'opacity' => OPACITY)
          end
        end
      end

      describe 'choropleth' do
        let(:property) { "actor_foll" }
        let(:number_of_buckets) { 7 }
        let(:qfunction) { "Quantile" }
        let(:color_ramp) { "red" }
        let(:choropleth_wizard_properties) do
          {
            "type" => "choropleth",
            "properties" =>
              {
                "property" => property,
                "method" => "#{number_of_buckets} Buckets",
                "qfunction" => qfunction,
                "color_ramp" => color_ramp,
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
          options = presenter_with_style_properties(layer).to_poro['options']
          @fill_color = options['style_properties']['properties']['fill']['color']
          @fill_size = options['style_properties']['properties']['fill']['size']
        end

        describe 'fill' do
          it 'has fixed size 10 by default' do
            expect(@fill_size).to include('fixed' => 10)
          end

          it 'transform color_ramp to color array in range' do
            # Commented because this might change soon
            # expect(@fill_color).to include('range' => "['#FFEDA0', '#FEB24C', '#F03B20']")
            expect(@fill_color).to include('range' => color_ramp)
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
      end

      describe 'category' do
        let(:property) { "aforo" }
        let(:opacity) { 0.456 }
        let(:marker_line_width) { 1 }
        let(:marker_line_color) { "#FFF" }
        let(:marker_line_opacity) { 0.7 }
        let(:title_1) { 100 }
        let(:title_2) { 200 }
        let(:category_wizard_properties) do
          {
            "type" => "category",
            "properties" => {
              "property" => property,
              "marker-width" => 10,
              "marker-opacity" => opacity,
              "marker-allow-overlap" => true,
              "marker-placement" => "point",
              "marker-type" => "ellipse",
              "marker-line-width" => marker_line_width,
              "marker-line-color" => marker_line_color,
              "marker-line-opacity" => marker_line_opacity,
              "zoom" => "15",
              "geometry_type" => 'point',
              "text-placement-type" => "simple",
              "text-label-position-tolerance" => 10,
              "categories" => [
                {
                  "title" => title_1,
                  "title_type" => "number",
                  "color" => COLOR_1,
                  "value_type" => "color"
                },
                {
                  "title" => title_2,
                  "title_type" => "number",
                  "color" => COLOR_2,
                  "value_type" => "color"
                }
              ]
            }
          }
        end

        describe 'point geometry type' do
          before(:each) do
            layer = build_layer_with_wizard_properties(category_wizard_properties)
            options = presenter_with_style_properties(layer).to_poro['options']
            @fill_color = options['style_properties']['properties']['fill']['color']
            @fill_size = options['style_properties']['properties']['fill']['size']
            @stroke_color = options['style_properties']['properties']['stroke']['color']
            @stroke_size = options['style_properties']['properties']['stroke']['size']
          end

          describe 'fill' do
            it 'has fill size fixed 10' do
              expect(@fill_size).to include('fixed' => 10)
            end

            it 'generates color range from categories colors' do
              expect(@fill_color).to include('range' => [COLOR_1, COLOR_2])
            end

            it 'generates domain from titles' do
              expect(@fill_color).to include('domain' => [title_1, title_2])
            end

            it 'property becomes attribute' do
              expect(@fill_color).to include('attribute' => property)
              expect(@fill_size).not_to include('attribute' => property)
            end

            it 'marker-opacity becomes opacity' do
              expect(@fill_color).to include('opacity' => opacity)
            end

            it 'bins defaults to 10' do
              expect(@fill_color).to include('bins' => 10)
            end
          end

          describe 'stroke' do
            it 'marker-line-width becomes fixed stroke size' do
              expect(@stroke_size).to include('fixed' => marker_line_width)
            end

            it 'marker-line-color becomes fixed stroke color' do
              expect(@stroke_color).to include('fixed' => marker_line_color)
            end

            it 'marker-line-opacity becomes opacity' do
              expect(@stroke_color).to include('opacity' => marker_line_opacity)
            end
          end
        end

        describe 'line geometry type' do
          before(:each) do
            properties = category_wizard_properties
            properties['properties']['geometry_type'] = 'line'
            layer = build_layer_with_wizard_properties(properties)

            options = presenter_with_style_properties(layer).to_poro['options']
            @stroke_color = options['style_properties']['properties']['stroke']['color']
            @stroke_size = options['style_properties']['properties']['stroke']['size']
          end

          it 'has fill size fixed 10' do
            expect(@stroke_size).to include('fixed' => 10)
          end

          it 'generates color range from categories colors' do
            expect(@stroke_color).to include('range' => [COLOR_1, COLOR_2])
          end

          it 'property becomes attribute' do
            expect(@stroke_color).to include('attribute' => property)
            expect(@stroke_size).not_to include('attribute' => property)
          end

          it 'marker-opacity becomes opacity' do
            expect(@stroke_color).to include('opacity' => opacity)
          end

          it 'bins defaults to 10' do
            expect(@stroke_color).to include('bins' => 10)
          end
        end
      end

      shared_examples_for 'torque wizard family' do
        describe 'animated' do
          it 'is enabled if it contains any torque-related properties' do
            expect(@animated).to include('enabled' => true)
          end

          it 'property becomes attribute' do
            expect(@animated).to include('attribute' => property)
          end

          it 'property becomes attribute only at animated' do
            expect(@fill['color']).not_to include('attribute' => property)
          end

          it 'torque-duration becomes duration' do
            expect(@animated).to include('duration' => torque_duration)
          end

          it 'torque-frame-count becomes steps' do
            expect(@animated).to include('steps' => torque_frame_count)
          end

          it 'torque-resolution becomes resolution' do
            expect(@animated).to include('resolution' => torque_resolution)
          end

          it 'torque-trails becomes trails' do
            expect(@animated).to include('trails' => torque_trails)
          end
        end
      end

      shared_examples_for 'torque blend wizard family' do
        describe 'torque-blend-mode' do
          it 'becomes blending' do
            expect(@properties).to include('blending' => torque_blend_mode)
          end
        end
      end

      describe 'torque' do
        it_behaves_like 'torque wizard family'
        it_behaves_like 'torque blend wizard family'

        let(:torque_blend_mode) { "lighter" }
        let(:property) { "fecha_date" }
        let(:torque_cumulative) { false }
        let(:torque_duration) { 30 }
        let(:torque_frame_count) { 256 }
        let(:torque_resolution) { 2 }
        let(:torque_trails) { 3 }
        let(:torque_wizard_properties) do
          {
            "type" => "torque",
            "properties" =>
              {
                "torque-cumulative" => torque_cumulative,
                "property" => property,
                "marker-type" => "ellipse",
                "layer-type" => "torque",
                "marker-width" => 6,
                "marker-fill" => "#0F3B82",
                "marker-opacity" => 0.9,
                "marker-line-width" => 0,
                "marker-line-color" => "#FFF",
                "marker-line-opacity" => 1,
                "torque-duration" => torque_duration,
                "torque-frame-count" => torque_frame_count,
                "torque-blend-mode" => torque_blend_mode,
                "torque-trails" => torque_trails,
                "torque-resolution" => torque_resolution,
                "zoom" => 15,
                "geometry_type" => "point"
              }
          }
        end

        before(:each) do
          layer = build_layer_with_wizard_properties(torque_wizard_properties)
          options = presenter_with_style_properties(layer).to_poro['options']
          @properties = options['style_properties']['properties']
          @animated = @properties['animated']
          @fill = @properties['fill']
          @fill_color = @fill['color']
          @fill_size = @fill['size']
        end

        it 'torque-cumulative becomes overlap' do
          expect(@animated).to include('overlap' => torque_cumulative)
        end
      end
    end

    describe 'torque cat' do
      it_behaves_like 'torque wizard family'
      it_behaves_like 'torque blend wizard family'

      let(:torque_blend_mode) { "lighter" }
      let(:property) { "fecha_date" }
      let(:property_cat) { "aforo" }
      let(:torque_duration) { 30 }
      let(:torque_frame_count) { 256 }
      let(:torque_resolution) { 2 }
      let(:torque_trails) { 3 }
      let(:torque_cat_wizard_properties) do
        {
          "type" => "torque",
          "properties" =>
            {
              "property" => property,
              "marker-type" => "ellipse",
              "layer-type" => "torque",
              "property_cat" => property_cat,
              "marker-width" => 6,
              "marker-fill" => "#0F3B82",
              "marker-opacity" => 0.9,
              "marker-line-width" => 0,
              "marker-line-color" => "#FFF",
              "marker-line-opacity" => 1,
              "torque-duration" => torque_duration,
              "torque-frame-count" => torque_frame_count,
              "torque-blend-mode" => torque_blend_mode,
              "torque-trails" => torque_trails,
              "torque-resolution" => torque_resolution,
              "zoom" => 15,
              "geometry_type" => "point",
              "categories" => [
                {
                  "title" => 100,
                  "title_type" => "number",
                  "color" => COLOR_1,
                  "value_type" => "color"
                },
                {
                  "title" => 200,
                  "title_type" => "number",
                  "color" => COLOR_2,
                  "value_type" => "color"
                }
              ]
            }
        }
      end

      before(:each) do
        layer = build_layer_with_wizard_properties(torque_cat_wizard_properties)
        options = presenter_with_style_properties(layer).to_poro['options']
        @properties = options['style_properties']['properties']
        @animated = @properties['animated']
        @fill = @properties['fill']
        @fill_color = @fill['color']
        @fill_size = @fill['size']
      end

      it 'generates color range from categories colors' do
        expect(@fill_color).to include('range' => [COLOR_1, COLOR_2])
      end
    end

    describe 'density' do
      let(:query_wrapper) { "with meta ... <%= sql %> ..." }
      let(:color_ramp) { "red" }
      let(:polygon_size) { 15 }
      let(:density_wizard_properties) do
        {
          "type" => "density",
          "properties" =>
            {
              "geometry_type" => "point",
              "method" => "5 Buckets",
              "color_ramp" => color_ramp,
              "polygon-opacity" => 0.8,
              "line-width" => 0.5,
              "line-color" => "#FFF",
              "line-opacity" => 1,
              "polygon-size" => polygon_size,
              "polygon-comp-op" => "none",
              "zoom" => 15
            }
        }
      end

      before(:each) do
        options = { 'query_wrapper' => query_wrapper, 'wizard_properties' => density_wizard_properties }
        layer = FactoryGirl.build(:carto_layer, options: options)
        @options = presenter_with_style_properties(layer).to_poro['options']

        @style = @options['style_properties']
        @aggregation = @style['aggregation']
        @properties = @style['properties']
        @fill_color = @properties['fill']['color']
      end

      it 'sets query_wrapper at sql_wrap' do
        @options['sql_wrap'].should eq query_wrapper
      end

      it 'maps point geometry_type to hexabins type' do
        expect(@style).to include('type' => 'hexabins')
      end

      it 'maps Rectangles geometry_type to squares type' do
        properties = density_wizard_properties
        properties['properties']['geometry_type'] = 'Rectangles'
        layer = build_layer_with_wizard_properties(properties)
        options = presenter_with_style_properties(layer).to_poro['options']
        expect(options['style_properties']).to include('type' => 'squares')
      end

      describe 'aggregation' do
        it 'has defaults' do
          expect(@aggregation).to include(
            "value" => {
              "operator" => 'COUNT',
              "attribute" => ''
            }
          )
        end

        it 'takes size from polygon-size' do
          expect(@aggregation).to include("size" => polygon_size)
        end
      end

      describe 'fill' do
        it 'transform color_ramp to color range' do
          # Commented because it might change soon
          # expect(@fill_color).to include('range' => "['#FFEDA0', '#FEB24C', '#F03B20']")
          expect(@fill_color).to include('range' => color_ramp)
        end
      end
    end

    describe 'heatmap' do
      it_behaves_like 'torque wizard family'

      let(:torque_resolution) { 8 }
      let(:marker_opacity) { 0.4 }
      let(:torque_trails) { 2 }
      let(:torque_frame_count) { 32 }
      let(:torque_duration) { 10 }
      let(:property) { "actor_post" }
      let(:heatmap_wizard_properties) do
        { "type" => "torque_heat",
          "properties" =>
            {
              "marker-width" => 35,
              "layer-type" => "torque",
              "marker-file" => "url(http://s3.amazonaws.com/com.cartodb.assets.static/alphamarker.png)",
              "image-filters" => "colorize-alpha(blue, cyan, lightgreen, yellow , orange, red)",
              "marker-opacity" => marker_opacity,
              "heat-animated" => true,
              "torque-cumulative" => false,
              "property" => property,
              "torque-duration" => torque_duration,
              "torque-frame-count" => torque_frame_count,
              "torque-trails" => torque_trails,
              "torque-resolution" => torque_resolution,
              "zoom" => 3,
              "geometry_type" => "point",
              "text-placement-type" => "simple",
              "text-label-position-tolerance" => 10
            }
          }
      end

      before(:each) do
        layer = build_layer_with_wizard_properties(heatmap_wizard_properties)
        options = presenter_with_style_properties(layer).to_poro['options']

        @style = options['style_properties']
        @properties = @style['properties']
        @animated = @properties['animated']
        @fill = @properties['fill']
        @fill_color = @fill['color']
        @fill_size = @fill['size']
      end

      it 'is generated from torque_heat' do
        expect(@style).to include('type' => 'heatmap')
      end

      describe 'aggregation' do
        before(:each) do
          @aggregation = @style['aggregation']
        end

        it 'takes size from torque-resolution' do
          expect(@aggregation).to include('size' => torque_resolution)
        end

        it 'has COUNT for value operator and empty string for attribute' do
          expect(@aggregation['value']).to include('operator' => 'COUNT', 'attribute' => '')
        end
      end

      describe 'properties' do
        before(:each) do
          @properties = @style['properties']
        end

        describe 'fill' do
          it 'has size fixed 35' do
            expect(@fill['size']).to include('fixed' => 35)
          end

          describe 'color' do
            before(:each) do
              @color = @fill['color']
            end

            it "has attribute: points_agg, default range color array, bins: 6 and opacity from marker_opacity" do
              expect(@color).to include('attribute' => 'points_agg',
                                        'range' => ['blue', 'cyan', 'lightgreen', 'yellow', 'orange', 'red'],
                                        'bins' => 6,
                                        'opacity' => marker_opacity)
            end
          end
        end
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

        it 'generates disabled labels' do
          layer = build_layer_with_wizard_properties(no_text_wizard_properties)
          options = presenter_with_style_properties(layer).to_poro['options']
          options['style_properties']['properties']['labels']['enabled'].should be_false
        end
      end

      describe 'with text-* properties' do
        let(:text_name) { "Something" }
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
          options = presenter_with_style_properties(layer).to_poro['options']
          @labels = options['style_properties']['properties']['labels']
        end

        it 'generates labels' do
          @labels.should_not be_nil
          @labels['enabled'].should be_true
        end

        it 'text-name generates attribute' do
          expect(@labels).to include('attribute' => text_name)
        end

        it 'text-name `None` generates `nil` attribute' do
          properties = text_wizard_properties
          properties['properties']['text-name'] = 'None'
          layer = build_layer_with_wizard_properties(properties)
          options = presenter_with_style_properties(layer).to_poro['options']
          labels = options['style_properties']['properties']['labels']
          expect(labels).to include('attribute' => nil)
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
            options = presenter_with_style_properties(layer).to_poro['options']
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
            options = presenter_with_style_properties(layer).to_poro['options']
            labels_halo_color = options['style_properties']['properties']['labels']['halo']['color']
            expect(labels_halo_color).to include('fixed' => text_halo_fill, 'opacity' => OPACITY)
          end
        end
      end
    end
  end
end
