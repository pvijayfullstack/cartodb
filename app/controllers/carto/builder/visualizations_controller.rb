# encoding: utf-8

require 'carto/api/vizjson3_presenter'
require 'carto/api/layer_presenter'

require_dependency 'carto/tracking/events'

module Carto
  module Builder
    class VisualizationsController < BuilderController
      include VisualizationsControllerHelper

      ssl_required :show

      before_filter :load_derived_visualization,
                    :redirect_to_editor_if_forced,
                    :auto_migrate_visualization_if_possible, only: :show
      before_filter :authors_only
      before_filter :editable_visualizations_only, only: :show

      # TODO: remove this when analysis logic lives in the backend
      before_filter :ensure_source_analyses, unless: :has_analyses?

      after_filter :update_user_last_activity,
                   :track_builder_visit, only: :show

      layout 'application_builder'

      def show
        @visualization_data = Carto::Api::VisualizationPresenter.new(@visualization, current_viewer, self).to_poro
        @layers_data = @visualization.layers.map do |l|
          Carto::Api::LayerPresenter.new(l, with_style_properties: true).to_poro(migrate_builder_infowindows: true)
        end
        @vizjson = generate_anonymous_map_vizjson3(@visualization, params)
        @state = @visualization.state.json
        @analyses_data = @visualization.analyses.map { |a| Carto::Api::AnalysisPresenter.new(a).to_poro }
        @basemaps = Cartodb.config[:basemaps].present? && Cartodb.config[:basemaps]
        @builder_notifications = builder_notifications
        @overlays_data = @visualization.overlays.map do |overlay|
          Carto::Api::OverlayPresenter.new(overlay).to_poro
        end
        @mapcaps_data = Carto::Api::MapcapPresenter.new(@visualization.latest_mapcap).to_poro
      end

      private

      def builder_notifications
        carto_viewer = current_viewer && Carto::User.where(id: current_viewer.id).first
        carto_viewer ? carto_viewer.notifications_for_category(:builder) : {}
      end

      def redirect_to_editor_if_forced
        if current_user.force_editor? || @visualization.open_in_editor?
          redirect_to CartoDB.url(self, 'public_visualizations_show_map', { id: params[:id] }, current_user)
        end
      end

      def load_derived_visualization
        @visualization = load_visualization_from_id_or_name(params[:id])
        render_404 unless @visualization && @visualization.derived?
      end

      def authors_only
        unauthorized unless !current_user.nil? && @visualization.writable_by?(current_user)
      end

      def editable_visualizations_only
        render_404 unless @visualization.editable?
      end

      def has_analyses?
        @visualization.analyses.any?
      end

      def ensure_source_analyses
        @visualization.add_source_analyses
        @visualization.reload
      end

      def unauthorized
        redirect_to CartoDB.url(self, 'builder_visualization_public_embed', visualization_id: request.params[:id])
      end

      def track_builder_visit
        current_viewer_id = current_viewer.id
        Carto::Tracking::Events::VisitedPrivatePage.new(current_viewer_id,
                                                        user_id: current_viewer_id,
                                                        page: 'builder').report
      end

      def auto_migrate_visualization_if_possible
        if @visualization.can_be_automatically_migrated?
          @visualization.version = 3
          @visualization.save
        end
      end
    end
  end
end
