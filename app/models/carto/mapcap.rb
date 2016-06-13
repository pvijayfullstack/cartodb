# encoding: utf-8

require_relative '../../services/carto/visualizations_export_service_2'

module Carto
  class Mapcap < ActiveRecord::Base
    include Carto::VisualizationsExportService2Importer
    include Carto::VisualizationsExportService2Exporter

    belongs_to :visualization, class_name: Carto::Visualization, foreign_key: 'visualization_id'

    before_save :generate_export_vizjson

    def regenerate_visualization
      regenerated_visualization = build_visualization_from_json_export(export_vizjson)

      regenerated_visualization.user = visualization.user

      visualization
    end

    private

    def generate_export_vizjson
      self.export_vizjson = export_visualization_json_string(vis_id, visualization.user)
    end
  end
end
