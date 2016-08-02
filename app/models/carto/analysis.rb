# encoding: UTF-8

require 'json'
require_relative './carto_json_serializer'

class Carto::Analysis < ActiveRecord::Base
  serialize :analysis_definition, ::Carto::CartoJsonSymbolizerSerializer
  validates :analysis_definition, carto_json_symbolizer: true
  validate :validate_user_not_viewer

  before_destroy :validate_user_not_viewer

  belongs_to :visualization, class_name: Carto::Visualization
  belongs_to :user, class_name: Carto::User

  after_save :update_map_dataset_dependencies
  after_save :notify_map_change
  after_destroy :notify_map_change

  def self.find_by_natural_id(visualization_id, natural_id)
    analysis = find_by_sql(
      [
        "select id from analyses where visualization_id = :visualization_id and analysis_definition ->> 'id' = :natural_id",
        { visualization_id: visualization_id, natural_id: natural_id }
      ]
    ).first
    # Load all data
    analysis.reload if analysis
    analysis
  end

  def self.source_analysis_for_layer(layer, index)
    map = layer.map
    visualization = map.visualization if map
    user = visualization.user if visualization

    visualization_id = visualization.id if visualization
    user_id = user.id if user

    analysis_definition = {
      id: 'abcdefghijklmnopqrstuvwxyz'[index] + '0',
      type: 'source',
      params: { query: layer.default_query(user) },
      options: { table_name: layer.options[:table_name] }
    }

    new(visualization_id: visualization_id, user_id: user_id, analysis_definition: analysis_definition)
  end

  def analysis_definition_for_api
    filter_valid_properties(analysis_node)
  end

  def natural_id
    pj = analysis_definition
    return nil unless pj
    pj[:id]
  end

  def map
    return nil unless visualization
    visualization.map
  end

  def analysis_node
    Carto::AnalysisNode.new(analysis_definition)
  end

  private

  # Analysis definition contains attributes not needed by Analysis API (see #7128).
  # This methods extract the needed ones.
  VALID_ANALYSIS_PROPERTIES = [:id, :type, :params].freeze

  def filter_valid_properties(node)
    valid = node.definition.select { |property, _| VALID_ANALYSIS_PROPERTIES.include?(property) }
    node.children_and_location.each do |location, child|
      child_in_hash = location.reduce(valid, :[])
      child_in_hash.replace(filter_valid_properties(child))
    end
    valid
  end

  def update_map_dataset_dependencies
    map.update_dataset_dependencies
  end

  def notify_map_change
    map.notify_map_change if map
  end

  def validate_user_not_viewer
    if user.viewer
      errors.add(:user, "Viewer users can't edit analyses")
      return false
    end
  end
end
