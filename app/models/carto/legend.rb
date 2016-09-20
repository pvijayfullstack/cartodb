# encoding utf-8

require_relative './carto_json_serializer'
require_relative '../../controllers/carto/api/legend_presenter'
require_dependency 'carto/lengend_definition_validator'

module Carto
  class Legend < ActiveRecord::Base
    self.inheritance_column = :_type

    belongs_to :layer, class_name: Carto::Layer

    VALID_LEGEND_TYPES = %(html category bubble choropleth custom).freeze

    serialize :definition, ::Carto::CartoJsonSerializer

    validates :definition, carto_json_symbolizer: true
    validates :pre_html, :post_html, :type, :layer_id, presence: true
    validates :type, inclusion: { in: VALID_LEGEND_TYPES }, allow_nil: true

    validate :on_data_layer,
             :under_max_legends_per_layer,
             :validate_definition_schema

    before_validation :ensure_definition

    private

    def ensure_definition
      self.definition ||= Hash.new
    end

    def on_data_layer
      unless layer.data_layer?
        errors.add(:layer_id, "'#{layer.kind}' layers can't have legends")
      end
    end

    MAX_LEGENDS_PER_LAYER = 2

    def under_max_legends_per_layer
      unless layer.legends.count < MAX_LEGENDS_PER_LAYER
        errors.add(:layer_id, 'Maximum number of legends per layer reached')
      end
    end

    def validate_definition_schema
      return unless type && definition

      definition_errors = Carto::LegendDefinitionValidator.errors(type, definition)

      errors.add(:definition, definition_errors.join(', ')) if definition_errors.any?
    end
  end
end
