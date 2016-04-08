require 'spec_helper_min'

describe Carto::VisualizationsExportService2 do
  let(:base_visualization_export) do
    {
      name: 'the name',
      description: 'the description',
      type: 'derived', # derived / remote / table / slide
      tags: ['tag 1', 'tag 2'],
      privacy: 'private', # private / link / public
      url_options: 'title=true&description=true&search=false&shareable=true&cartodb_logo=true' +
        '&layer_selector=false&legends=false&scrollwheel=true&fullscreen=true&sublayer_options=1&sql=',
      source: 'the source',
      license: 'mit',
      title: 'the title',
      kind: 'geom', # geom / raster
      attributions: 'the attributions',
      bbox: '0103000000010000000500000031118AC72D246AC1A83916DE775E51C131118AC72D246AC18A9C928550D5614101D5E410F03E7' +
        '0418A9C928550D5614101D5E410F03E7041A83916DE775E51C131118AC72D246AC1A83916DE775E51C1',
      display_name: 'the display_name',
      map: {
        provider: 'leaflet',
        bounding_box_sw: [-85.0511, -179],
        bounding_box_ne: [85.0511, 179],
        center: [34.672410587, 67.90919030050006],
        zoom: 1,
        view_bounds_sw: [15.775376695, -18.1672257149999],
        view_bounds_ne: [53.569444479, 153.985606316],
        scrollwheel: false,
        legends: true
      },
      layers: [
        {
          options: '{"default":true,"url":"http://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}.png",' +
            '"subdomains":"abcd","minZoom":"0","maxZoom":"18","name":"Positron",' +
            '"className":"positron_rainbow_labels","attribution":"\u00a9 <a ' +
            'href=\"http://www.openstreetmap.org/copyright\">OpenStreetMap</a> contributors \u00a9 ' +
            '<a href=\"http://cartodb.com/attributions#basemaps\">CartoDB</a>",' +
            '"labels":{"url":"http://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}.png"},' +
            '"urlTemplate":"http://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}.png"}',
          kind: 'tiled'
        },
        {
          options: '{"attribution":"CartoDB <a href=\"http://cartodb.com/attributions\" ' +
            'target=\"_blank\">attribution</a>","type":"CartoDB","active":true,"query":"","opacity":0.99,' +
            '"interactivity":"cartodb_id","interaction":true,"debug":false,"tiler_domain":"localhost.lan",' +
            '"tiler_port":"80","tiler_protocol":"http","sql_api_domain":"cartodb.com","sql_api_port":"80",' +
            '"sql_api_protocol":"http","extra_params":{"cache_policy":"persist","cache_buster":1459849314400},' +
            '"cdn_url":null,"maxZoom":28,"auto_bound":false,"visible":true,"sql_domain":"localhost.lan",' +
            '"sql_port":"80","sql_protocol":"http","tile_style_history":["#guess_ip_1 {\n  marker-fill: #FF6600;\n  ' +
            'marker-opacity: 0.9;\n  marker-width: 12;\n  marker-line-color: white;\n  marker-line-width: 3;\n  ' +
            'marker-line-opacity: 0.9;\n  marker-placement: point;\n  marker-type: ellipse;\n  ' +
            'marker-allow-overlap: true;\n}"],"style_version":"2.1.1","table_name":"guess_ip_1",' +
            '"user_name":"juanignaciosl","tile_style":"/** simple visualization */\n\n#guess_ip_1{\n  ' +
            'marker-fill-opacity: 0.9;\n  marker-line-color: #FFF;\n  marker-line-width: 1;\n  ' +
            'marker-line-opacity: 1;\n  marker-placement: point;\n  marker-type: ellipse;\n  marker-width: 10;\n  ' +
            'marker-fill: #FF6600;\n  marker-allow-overlap: true;\n}","id":"dbb6826a-09e5-4238-b81b-86a43535bf02",' +
            '"order":1,"use_server_style":true,"query_history":[],"stat_tag":"9e82a99a-fb12-11e5-80c0-080027880ca6",' +
            '"maps_api_template":"http://{user}.localhost.lan:8181","cartodb_logo":false,"no_cdn":false,' +
            '"force_cors":true,"tile_style_custom":false,"query_wrapper":null,"query_generated":false,' +
            '"wizard_properties":{"type":"polygon","properties":{"marker-width":10,"marker-fill":"#FF6600",' +
            '"marker-opacity":0.9,"marker-allow-overlap":true,"marker-placement":"point","marker-type":"ellipse",' +
            '"marker-line-width":1,"marker-line-color":"#FFF","marker-line-opacity":1,"marker-comp-op":"none",' +
            '"text-name":"None","text-face-name":"DejaVu Sans Book","text-size":10,"text-fill":"#000",' +
            '"text-halo-fill":"#FFF","text-halo-radius":1,"text-dy":-10,"text-allow-overlap":true,' +
            '"text-placement-type":"dummy","text-label-position-tolerance":0,"text-placement":"point",' +
            '"geometry_type":"point"}},"legend":{"type":"none","show_title":false,"title":"","template":"",' +
            '"visible":true}}',
          kind: 'carto',
          infowindow: '{"fields":[],"template_name":"table/views/infowindow_light","template":"",' +
            '"alternative_names":{},"width":226,"maxHeight":180}',
          tooltip: '{"fields":[],"template_name":"tooltip_light","template":"","alternative_names":{},"maxHeight":180}}'
        },
        {
          options: '{"default":true,"url":"http://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}.png", ' +
            '"subdomains":"abcd","minZoom":"0","maxZoom":"18","attribution":"\u00a9 <a ' +
            'href=\"http://www.openstreetmap.org/copyright\">OpenStreetMap</a> contributors \u00a9 ' +
            '<a href=\"http://cartodb.com/attributions#basemaps\">CartoDB</a>",' +
            '"urlTemplate":"http://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}.png","type":"Tiled",' +
            '"name":"Positron Labels"}',
          kind: 'tiled'
        }
      ],
      overlays: [
        {
          options: '{"display":true,"x":20,"y":20}',
          type: 'share'
        },
        {
          options: '{"display":true,"x":20,"y":150}',
          type: 'loader',
          template: '<div class="loader" original-title=""></div>'
        }
      ]

      # TODO:
      # permission? Probably not needed.
      # active_layer_id.
      # parent_id / prev_id / next_id / slide_transition_options / active_child
      # user_tables
      # analyses
      # widgets
    }
  end

  let(:export) do
    {
      visualization: base_visualization_export,
      version: 2
    }
  end

  describe 'importing' do
    describe '#build_visualization_from_json_export' do
      it 'fails if version is not 2' do
        expect {
          Carto::VisualizationsExportService2.new.build_visualization_from_json_export(export.merge(version: 1).to_json)
        }.to raise_error("Wrong export version")
      end

      it 'builds base visualization' do
        visualization = Carto::VisualizationsExportService2.new.build_visualization_from_json_export(export.to_json)

        visualization_export = export[:visualization]
        visualization.name.should eq visualization_export[:name]
        visualization.description.should eq visualization_export[:description]
        visualization.type.should eq visualization_export[:type]
        visualization.tags.should eq visualization_export[:tags]
        visualization.privacy.should eq visualization_export[:privacy]
        visualization.url_options.should eq visualization_export[:url_options]
        visualization.source.should eq visualization_export[:source]
        visualization.license.should eq visualization_export[:license]
        visualization.title.should eq visualization_export[:title]
        visualization.kind.should eq visualization_export[:kind]
        visualization.attributions.should eq visualization_export[:attributions]
        visualization.bbox.should eq visualization_export[:bbox]
        visualization.display_name.should eq visualization_export[:display_name]

        visualization.id.should be_nil # Not set until persistence
        visualization.user_id.should be_nil # Import build step is "user-agnostic"
        visualization.created_at.should be_nil # Not set until persistence
        visualization.updated_at.should be_nil # Not set until persistence
        visualization.encrypted_password.should be_nil
        visualization.password_salt.should be_nil
        visualization.locked.should be_false

        map_export = base_visualization_export[:map]
        map = visualization.map
        map.provider.should eq map_export[:provider]
        map.bounding_box_sw.should eq map_export[:bounding_box_sw]
        map.bounding_box_ne.should eq map_export[:bounding_box_ne]
        map.center.should eq map_export[:center]
        map.zoom.should eq map_export[:zoom]
        map.view_bounds_sw.should eq map_export[:view_bounds_sw]
        map.view_bounds_ne.should eq map_export[:view_bounds_ne]
        map.scrollwheel.should eq map_export[:scrollwheel]
        map.legends.should eq map_export[:legends]

        map.id.should be_nil # Not set until persistence
        map.updated_at.should be_nil # Not set until persistence
        map.user_id.should be_nil # Import build step is "user-agnostic"

        layers_export = base_visualization_export[:layers]
        layers = visualization.layers
        layers.length.should eq layers_export.length
        for i in 0..2 do
          layer = layers[i]
          layer.order.should eq i

          layer_export = layers_export[i]
          layer.options.should eq layer_export[:options]
          layer.kind.should eq layer_export[:kind]
          layer.infowindow.should eq layer_export[:infowindow]
          layer.tooltip.should eq layer_export[:tooltip]
          layer.updated_at.should be_nil
          layer.id.should be_nil
        end
      end
    end
  end
end
