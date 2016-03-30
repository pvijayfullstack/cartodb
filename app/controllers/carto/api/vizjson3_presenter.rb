require_dependency 'carto/api/layer_vizjson_adapter'
require_dependency 'cartodb/redis_vizjson_cache'

module Carto
  module Api
    class VizJSON3Presenter
      # WIP #6953: remove adapters
      def initialize(visualization, viewer_user, redis_vizjson_cache = CartoDB::Visualization::RedisVizjsonCache.new($tables_metadata, 3))
        @visualization = visualization
        @viewer_user = viewer_user
        @map = visualization.map
        @redis_vizjson_cache = redis_vizjson_cache
      end

      def to_vizjson(**options)
        @redis_vizjson_cache.cached(@visualization.id, options.fetch(:https_request, false)) do
          vizjson = calculate_vizjson(options)
          vizjson[:widgets] = Carto::Widget.from_visualization_id(@visualization.id).map do |w|
            Carto::Api::WidgetPresenter.new(w).to_poro
          end

          vizjson[:layers].each { |l| layer_vizjson2_to_3(l) }

          vizjson[:datasource] = datasource(options)
          vizjson[:user] = user_vizjson_info
          vizjson[:vector] = options.fetch(:vector, false)

          vizjson
        end
      end

      private

      attr_reader :visualization, :map

      VIZJSON_VERSION = '3.0.0'.freeze

      def default_options
        {
          full: true,
          visualization_id: visualization.id,
          https_request: false,
          attributions: visualization.attributions_from_derived_visualizations
        }
      end

      def add_default_options(options = {})
        default_options.merge(
          full: false,
          user_name: user.username,
          user_api_key: user.api_key,
          user: user,
          viewer_user: @viewer_user
        ).merge(options)
      end

      def calculate_vizjson(options = {})
        options = add_default_options(options)

        poro_data = {
          id:             visualization.id,
          version:        VIZJSON_VERSION,
          title:          visualization.qualified_name(user),
          likes:          visualization.likes.count,
          description:    html_safe(visualization.description),
          scrollwheel:    map.scrollwheel,
          legends:        map.legends,
          url:            options.delete(:url),
          map_provider:   map.provider,
          bounds:         bounds_from(map),
          center:         map.center,
          zoom:           map.zoom,
          updated_at:     map.viz_updated_at,
          layers:         layers_for(visualization, options),
          overlays:       overlays_for(visualization),
          prev:           visualization.prev_id,
          next:           visualization.next_id,
          transition_options: visualization.transition_options
        }

        auth_tokens = @visualization.needed_auth_tokens
        poro_data.merge!(auth_tokens: auth_tokens) if auth_tokens.length > 0

        children_vizjson = children_for(@visualization, options)
        poro_data.merge!(slides: children_vizjson) if children_vizjson.length > 0
        unless visualization.parent_id.nil?
          poro_data[:title] = visualization.parent.qualified_name(user)
          poro_data[:description] = html_safe(visualization.parent.description)
        end

        symbolize_vizjson(poro_data)
      end

      def children_for(visualization, options)
        visualization.children.map do |child|
          VizJSON3Presenter.new(child, @viewer_user, @redis_vizjson_cache).to_vizjson(options)
        end
      end

      def overlays_for(visualization)
        visualization.overlays.to_a.map do |overlay|
          Carto::Api::OverlayPresenter.new(overlay).to_vizjson_poro
        end
      end

      def bounds_from(map)
        ::JSON.parse("[#{map.view_bounds_sw}, #{map.view_bounds_ne}]")
      rescue => e
        CartoDB::Logger.debug(
          message: "Error parsing map bounds: #{map.id}, #{map.view_bounds_sw}, #{map.view_bounds_ne}",
          exception: e)
      end

      def layers_for(visualization, options)
        basemap_layer = basemap_layer_for(visualization, options)
        layers_data = []
        layers_data.push(basemap_layer) if basemap_layer

        if visualization.retrieve_named_map?
          presenter_options = {
            user_name: options.fetch(:user_name),
            api_key: options.delete(:user_api_key),
            https_request: options.fetch(:https_request, false),
            viewer_user: @viewer_user,
            owner: visualization.user
          }
          named_maps_presenter = VizJSON3NamedMapPresenter.new(
            visualization, layer_group_for_named_map(visualization, options), presenter_options, configuration)
          layers_data.push(named_maps_presenter.to_poro)
        else
          named_maps_presenter = nil
          layers_data.push(layer_group_for(visualization, options))
        end
        layers_data.push(other_layers_for(visualization, options, named_maps_presenter))

        layers_data += non_basemap_base_layers_for(visualization, options)

        layers_data.compact.flatten
      end

      def layer_group_for_named_map(visualization, options)
        layer_group_poro = layer_group_for(visualization, options)
        # If there is *only* a torque layer, there is no layergroup
        return {} if layer_group_poro.nil?

        layers_data = Array.new
        layer_num = 0
        layer_group_poro[:options][:layer_definition][:layers].each do |layer|
          layers_data.push(type:       layer[:type],
                           options:    layer[:options],
                           visible:    layer[:visible],
                           index:      layer_num
                          )
          layer_num += 1
        end
        layers_data
      end

      def layer_group_for(visualization, options)
        LayerGroup::Presenter.new(
          visualization.data_layers.map { |l| Carto::Api::LayerVizJSONAdapter.new(l) },
          options, configuration).to_poro
      end

      def named_map_layer_group_for(visualization, options)
        LayerGroup::Presenter.new(
          visualization.named_map_layers.map { |l| Carto::Api::LayerVizJSONAdapter.new(l) },
          options, configuration).to_poro
      end

      def other_layers_for(visualization, options, named_maps_presenter = nil)
        layer_index = visualization.data_layers.size

        visualization.other_layers.map do |layer|
          decoration_data_to_apply = if named_maps_presenter.nil?
                                       {}
                                     else
                                       named_maps_presenter.get_decoration_for_layer(layer.kind, layer_index)
                                     end
          layer_index += 1
          CartoDB::LayerModule::Presenter.new(
            Carto::Api::LayerVizJSONAdapter.new(layer),
            options, configuration, decoration_data_to_apply).to_vizjson_v2
        end
      end

      # TODO: remove? This method is the equivalent to CartoDB::Visualization::VizJSON, needed by `to_export_poro`.
      # Delete if it's not needed for #6365, which will probably replace the old exporting method.
      def all_layers_for(visualization, options)
        layers_data = []

        basemap_layer = basemap_layer_for(visualization, options)
        layers_data.push(basemap_layer) if basemap_layer

        data_layers = visualization.data_layers.map do |layer|
          CartoDB::LayerModule::Presenter.new(
            Carto::Api::LayerVizJSONAdapter.new(layer),
            options, configuration).to_vizjson_v2
        end
        layers_data.push(data_layers)

        layers_data.push(other_layers_for(visualization))

        layers_data += non_basemap_base_layers_for(visualization, options)

        layers_data.compact.flatten
      end

      # INFO: Assumes layers come always ordered by order (they do)
      def basemap_layer_for(visualization, options)
        layer = visualization.user_layers.first
        CartoDB::LayerModule::Presenter.new(
          Carto::Api::LayerVizJSONAdapter.new(layer),
          options, configuration).to_vizjson_v2 unless layer.nil?
      end

      # INFO: Assumes layers come always ordered by order (they do)
      def non_basemap_base_layers_for(visualization, options)
        base_layers = visualization.user_layers
        unless base_layers.empty?
          # Remove the basemap, which is always first
          base_layers.slice(1, visualization.user_layers.length)
                     .map do |layer|
            CartoDB::LayerModule::Presenter.new(
              Carto::Api::LayerVizJSONAdapter.new(layer),
              options, configuration).to_vizjson_v2
          end
        else
          []
        end
      end

      def configuration
        Cartodb.config
      end

      def user
        @user ||= @visualization.user
      end

      def datasource(options)
        api_templates_type = options.fetch(:https_request, false) ? 'private' : 'public'
        ds = {
          user_name: @visualization.user.username,
          maps_api_template: ApplicationHelper.maps_api_template(api_templates_type),
          stat_tag: @visualization.id
        }

        ds[:template_name] = CartoDB::NamedMapsWrapper::NamedMap.template_name(@visualization.id) if @visualization.retrieve_named_map?

        ds
      end

      def user_vizjson_info
        {
          fullname: user.name.present? ? user.name : user.username,
          avatar_url: user.avatar_url
        }
      end

      def html_safe(string)
        if string.present?
          renderer = Redcarpet::Render::Safe
          markdown = Redcarpet::Markdown.new(renderer, extensions = {})
          markdown.render string
        end
      end

      # WIP #6953: remove next methods patch v2 vizjson #####################################

      def symbolize_vizjson(vizjson)
        vizjson = vizjson.deep_symbolize_keys
        vizjson[:layers] = vizjson[:layers].map(&:deep_symbolize_keys)
        vizjson
      end

      def layer_vizjson2_to_3(layer_data)
        if layer_data[:type] == 'torque'
          torque_layer_vizjson2_to_3(layer_data)
        end

        layer_definitions_from_layer_data(layer_data).each do |layer_definition|
          infowindow = layer_definition[:infowindow]
          if infowindow
            infowindow_sym = infowindow.deep_symbolize_keys
            infowindow[:template] = v3_infowindow_template(infowindow_sym[:template_name], infowindow_sym[:template])
          end

          tooltip = layer_definition[:tooltip]
          if tooltip
            tooltip_sym = tooltip.deep_symbolize_keys
            tooltip[:template] = v3_tooltip_template(tooltip_sym[:template_name], tooltip_sym[:template])
          end
        end
      end

      # WIP #6953: refactor, ugly as hell. Technical debt: #6953
      def layer_definitions_from_layer_data(layer_data)
        if layer_data[:options] &&
           layer_data[:options][:layer_definition] &&
           layer_data[:options][:layer_definition][:layers]
          layer_data[:options][:layer_definition][:layers]
        elsif layer_data[:options] &&
              layer_data[:options][:named_map] &&
              layer_data[:options][:named_map][:layers]
          layer_data[:options][:named_map][:layers]
        else
          []
        end
      end

      def v3_infowindow_template(template_name, fallback_template)
        template_name = Carto::Api::LayerVizJSONAdapter::TEMPLATES_MAP.fetch(template_name, template_name)
        if template_name.present?
          path = Rails.root.join("lib/assets/javascripts/cartodb3/mustache-templates/infowindows/#{template_name}.jst.mustache")
          File.read(path)
        else
          fallback_template
        end
      end

      def v3_tooltip_template(template_name, fallback_template)
        template_name = Carto::Api::LayerVizJSONAdapter::TEMPLATES_MAP.fetch(template_name, template_name)
        if template_name.present?
          path = Rails.root.join("lib/assets/javascripts/cartodb3/mustache-templates/tooltips/#{template_name}.jst.mustache")
          File.read(path)
        else
          fallback_template
        end
      end

      def torque_layer_vizjson2_to_3(layer_data)
        layer_options = layer_data[:options]

        layer_options[:cartocss] = layer_options[:tile_style]
        layer_options.delete(:tile_style)

        layer = @visualization.layers.select { |l| l.id == layer_data[:id] }.first
        layer_options[:cartocss_version] = layer.options['style_version'] if layer
        layer_options.delete(:style_version)

        layer_options[:sql] = if layer_options[:query].present? || layer.nil?
                                layer_options[:query]
                              else
                                layer.options['query']
                              end
        layer_options.delete(:query)
      end
    end

    class VizJSON3NamedMapPresenter

      NAMED_MAP_TYPE = 'namedmap'.freeze
      LAYER_TYPES_TO_DECORATE = ['torque'].freeze
      DEFAULT_TILER_FILTER = 'mapnik'.freeze

      # @throws NamedMapsPresenterError
      def initialize(visualization, layergroup, options, configuration)
        @visualization    = visualization
        @options          = options
        @configuration    = configuration
        @layergroup_data  = layergroup
        @named_map_name   = CartoDB::NamedMapsWrapper::NamedMap.template_name(@visualization.id)
      end

      # Prepares additional data to decorate layers in the LAYER_TYPES_TO_DECORATE list
      # - Parameters set inside as nil will remove the field itself from the layer data
      # @throws NamedMapsPresenterError
      def get_decoration_for_layer(layer_type, layer_index)
        return {} unless LAYER_TYPES_TO_DECORATE.include? layer_type

        {
          'named_map' => {
            'name' =>         @named_map_name,
            'layer_index' =>  layer_index,
            'params' =>       placeholders_data
          },
          'query' => nil # do not expose SQL query on Torque layers with named maps
        }
      end

      # Prepare a PORO (Hash object) for easy JSONification
      # @see https://github.com/CartoDB/cartodb.js/blob/privacy-maps/doc/vizjson_format.md
      # @throws NamedMapsPresenterError
      def to_poro
        if @visualization.data_layers.empty?
          nil # When there are no layers don't return named map data
        else
          api_templates_type = @options.fetch(:https_request, false) ? 'private' : 'public'
          privacy_type = @visualization.password_protected? ? 'private' : api_templates_type
          {
            type:     NAMED_MAP_TYPE,
            order:    1,
            options:  {
              type:             NAMED_MAP_TYPE,
              user_name:        @options.fetch(:user_name),
              maps_api_template: ApplicationHelper.maps_api_template(privacy_type),
              sql_api_template: ApplicationHelper.sql_api_template(privacy_type),
              # tiler_* and sql_api_* are kept for backwards compatibility
              tiler_protocol:   @visualization.password_protected? ?
                                  @configuration[:tiler]['private']['protocol'] :
                                  @configuration[:tiler]['public']['protocol'],
              tiler_domain:     @visualization.password_protected? ?
                                  @configuration[:tiler]['private']['domain'] :
                                  @configuration[:tiler]['public']['domain'],
              tiler_port:       @visualization.password_protected? ?
                                  @configuration[:tiler]['private']['port'] :
                                  @configuration[:tiler]['public']['port'],
              filter:           @configuration[:tiler].fetch('filter', DEFAULT_TILER_FILTER),
              named_map:        {
                name:     @named_map_name,
                stat_tag: @visualization.id,
                params:   placeholders_data,
                layers:   configure_layers_data
              },
              attribution: @visualization.attributions_from_derived_visualizations.join(', ')
            }
          }
        end
      end

      private

      def placeholders_data
        data = {}
        @layergroup_data.each do |layer|
          data["layer#{layer[:index].to_s}".to_sym] = layer[:visible] ? 1 : 0
        end
        data
      end

      # Extract relevant information from layers
      def configure_layers_data
        # Http/base layers don't appear at viz.json
        layers = @visualization.data_layers
        layers_data = Array.new
        layers.each do |layer|
          layer_vizjson = CartoDB::LayerModule::Presenter.new(
            Carto::Api::LayerVizJSONAdapter.new(layer), @options, @configuration).to_vizjson_v2
          layers_data.push(data_for_carto_layer(layer_vizjson))
        end
        layers_data
      end

      def data_for_carto_layer(layer_vizjson)
        # TODO: this id will probably be removed from named maps
        data = {
            id: layer_vizjson[:id],
            layer_name: layer_vizjson[:options][:layer_name],
            interactivity: layer_vizjson[:options][:interactivity],
            visible: layer_vizjson[:visible]
          }

        if layer_vizjson.include?(:infowindow) && !layer_vizjson[:infowindow].nil? &&
             !layer_vizjson[:infowindow].fetch('fields').nil? && layer_vizjson[:infowindow].fetch('fields').size > 0
          data[:infowindow] = layer_vizjson[:infowindow]
        end

        if layer_vizjson.include?(:tooltip) && !layer_vizjson[:tooltip].nil? &&
             !layer_vizjson[:tooltip].fetch('fields').nil? && layer_vizjson[:tooltip].fetch('fields').size > 0
          data[:tooltip] = layer_vizjson[:tooltip]
        end

        if layer_vizjson.include?(:legend) && !layer_vizjson[:legend].nil? &&
             layer_vizjson[:legend].fetch('type') != 'none'
          data[:legend] = layer_vizjson[:legend]
        end
        data
      end

      # Loads the data of a given named map
      # It completes/overrides data from the children if visualization has a parent_id
      def load_named_map_data
        named_maps = CartoDB::NamedMapsWrapper::NamedMaps.new(
            {
              name:     @options.fetch(:user_name),
              api_key:  @options.fetch(:api_key)
            },
            {
              protocol:   @configuration[:tiler]['internal']['protocol'],
              domain:     @configuration[:tiler]['internal']['domain'],
              port:       @configuration[:tiler]['internal']['port'],
              verifycert: (@configuration[:tiler]['internal']['verifycert'] rescue true)
            }
          )
        @named_map = named_maps.get(CartoDB::NamedMapsWrapper::NamedMap.template_name(@visualization.id))
        unless @named_map.nil?
          if @visualization.parent_id.nil?
            @named_map_template = @named_map.template.fetch(:template)
          else
            parent_named_map = named_maps.get(CartoDB::NamedMapsWrapper::NamedMap.template_name(@visualization.parent_id))
            @named_map_template = parent_named_map.template.fetch(:template).merge(@named_map.template.fetch(:template))
          end
        end
        @loaded = true
      end
    end
  end
end
