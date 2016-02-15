require 'carto/api/vizjson3_presenter'

module Carto
  module Editor
    class VisualizationsController < EditorController
      include VisualizationsControllerHelper

      ssl_required :show

      before_filter :load_visualization, only: [:show]
      before_filter :only_edit_users, only: [:show]
      before_filter :only_editable_visualizations, only: [:show]

      after_filter :update_user_last_activity, only: [:show]

      layout 'application_editor3'

      def show
        @visualization_data = Carto::Api::VisualizationPresenter.new(@visualization, current_viewer, self).to_poro
        @vizjson = Carto::Api::VizJSON3Presenter.new(@visualization, $tables_metadata)
                                                .to_vizjson(https_request: is_https?)
      end

      private

      def load_visualization
        @visualization = load_visualization_from_id(params[:id])
      end

      def only_edit_users
        render_403 unless !current_user.nil? && @visualization.is_writable_by_user(current_user)
      end

      def only_editable_visualizations
        render_403 unless @visualization.is_editable?
      end
    end
  end
end
