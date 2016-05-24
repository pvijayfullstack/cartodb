# encoding: utf-8
require_dependency 'carto/uuidhelper'
require_relative '../editor/editor_users_module'

module Carto
  module Api
    class AnalysesController < ::Api::ApplicationController
      include Carto::ControllerHelper
      include Carto::UUIDHelper
      include Carto::Editor::EditorUsersModule

      ssl_required :show, :create, :update, :destroy

      before_filter :editor_users_only
      before_filter :load_visualization
      before_filter :check_user_can_add_analysis, only: [:show, :create, :update, :destroy]
      before_filter :load_analysis, only: [:show, :update, :destroy]

      rescue_from StandardError, with: :rescue_from_standard_error
      rescue_from Carto::LoadError, with: :rescue_from_carto_error
      rescue_from Carto::UnauthorizedError, with: :rescue_from_carto_error
      rescue_from Carto::UnprocesableEntityError, with: :rescue_from_carto_error

      def show
        render_jsonp(AnalysisPresenter.new(@analysis).to_poro)
      end

      def create
        analysis = Carto::Analysis.new(
          visualization_id: @visualization.id,
          user_id: current_user.id,
          analysis_definition: analysis_definition_from_request
        )
        analysis.save!
        render_jsonp(AnalysisPresenter.new(analysis).to_poro, 201)
      end

      def update
        @analysis.analysis_definition = analysis_definition_from_request
        @analysis.save!
        render_jsonp(AnalysisPresenter.new(@analysis).to_poro, 200)
      end

      def destroy
        @analysis.destroy
        render_jsonp(AnalysisPresenter.new(@analysis).to_poro, 200)
      end

      private

      def analysis_definition_from_request
        analysis_json = json_post(request.raw_post)

        if analysis_json.nil? || analysis_json.empty?
          raise Carto::UnprocesableEntityError.new("Empty analysis")
        end

        analysis_definition = analysis_json['analysis_definition']
        if analysis_definition.nil? || analysis_definition.empty? || analysis_definition.class == String
          raise Carto::UnprocesableEntityError.new("Invalid analysis definition")
        end

        analysis_definition
      end

      def json_post(raw_post = request.raw_post)
        @json_post ||= (raw_post.present? ? JSON.parse(raw_post) : nil)
      rescue => e
        # Malformed JSON is not our business
        CartoDB.notify_warning_exception(e)
        raise UnprocesableEntityError.new("Malformed JSON: #{raw_post}")
      end

      def load_visualization
        visualization_id = params[:visualization_id]

        if payload_visualization_id.present? && payload_visualization_id != visualization_id
          raise UnprocesableEntityError.new("url vis (#{visualization_id}) != payload (#{payload_visualization_id})")
        end

        @visualization = Carto::Visualization.where(id: visualization_id).first if visualization_id
        raise LoadError.new("Visualization not found: #{visualization_id}") unless @visualization
      end

      def payload_visualization_id
        json_post.present? ? json_post['visualization_id'] : nil
      end

      def payload_analysis_id
        json_post.present? ? json_post['id'] : nil
      end

      def check_user_can_add_analysis
        if @visualization.user_id != current_user.id
          raise Carto::UnauthorizedError.new("#{current_user.id} doesn't own visualization #{@visualization.id}")
        end
      end

      def load_analysis
        if payload_analysis_id.present? && payload_analysis_id != params[:id]
          raise UnprocesableEntityError.new("url analysis (#{params[:id]}) != payload (#{payload_analysis_id})")
        end

        unless params[:id].nil?
          @analysis = Carto::Analysis.where(id: params[:id]).first if is_uuid?(params[:id])

          if @analysis.nil?
            @analysis = Carto::Analysis.find_by_natural_id(@visualization.id, params[:id])
          end
        end

        raise Carto::LoadError.new("Analysis not found: #{params[:id]}") unless @analysis
      end
    end
  end
end
