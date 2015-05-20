module Carto
  module Api
    class ImportsController < ::Api::ApplicationController

      ssl_required :index, :show
      ssl_allowed :service_token_valid?

      def index
        imports = DataImportsService.new.process_recent_user_imports(current_user)
        render json: { imports: imports.map(&:id), success: true }
      end

      def show
        import = DataImportsService.new.process_by_id(params[:id])
        render_404 and return if import.nil?

        data = import.api_public_values
        if import.state == Carto::DataImport::STATE_COMPLETE
          data[:any_table_raster] = import.is_raster?

          decorate_twitter_import_data!(data, import)
          decorate_default_visualization_data!(data, import)
        end

        render json: data
      end

      def service_token_valid?
        oauth = logged_user.get_synchronization_oauth(params[:id])

        return render_jsonp({ oauth_valid: false, success: true }) if oauth.nil?

        valid = logged_user.validate_oauth(oauth)

        render_jsonp({ oauth_valid: valid, success: true })
      rescue => e
        CartoDB.notify_exception(e)
        render_jsonp({ errors: e.message }, 400)
      end

      private

      # TODO: this should be moved upwards in the controller hierarchy, and make it a replacement for current_user
      def logged_user
        @logged_user ||= Carto::User.where(id: current_user.id).first
      end

      def decorate_twitter_import_data!(data, data_import)
        return if data_import.service_name != CartoDB::Datasources::Search::Twitter::DATASOURCE_NAME

        audit_entry = ::SearchTweet.where(data_import_id: data_import.id).first
        data[:tweets_georeferenced] = audit_entry.retrieved_items
        data[:tweets_cost] = audit_entry.price
        data[:tweets_overquota] = audit_entry.user.remaining_twitter_quota == 0
      end

      def decorate_default_visualization_data!(data, data_import)
        derived_vis_id = nil

        if data_import.create_visualization && !data_import.visualization_id.nil?
          derived_vis_id = data_import.visualization_id
        end

        data[:derived_visualization_id] = derived_vis_id
      end

    end
  end
end
