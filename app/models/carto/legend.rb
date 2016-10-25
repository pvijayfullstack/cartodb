# encoding utf-8

require_relative './carto_json_serializer'
require_relative '../../controllers/carto/api/legend_presenter'
require_dependency 'carto/legend_definition_validator'

module Carto
  class Legend < ActiveRecord::Base
    self.inheritance_column = :_type

    belongs_to :layer, class_name: Carto::Layer

    VALID_LEGEND_TYPES = %(html category bubble choropleth custom custom_choropleth).freeze

    serialize :definition, ::Carto::CartoJsonSerializer

    validates :definition, carto_json_symbolizer: true
    validates :type, :layer, presence: true
    validates :type, inclusion: { in: VALID_LEGEND_TYPES }, allow_nil: true

    validate :on_data_layer,
             :under_max_legends_per_layer,
             :validate_definition_schema

    before_validation :ensure_definition

    after_commit :force_notify_layer_change

    private

    def ensure_definition
      self.definition ||= Hash.new
    end

    def on_data_layer
      if layer && !layer.data_layer?
        errors.add(:layer, "'#{layer.kind}' layers can't have legends")
      end
    end

    MAX_LEGENDS_PER_LAYER = 2

    def under_max_legends_per_layer
      if layer
        other_legends = layer.legends.select { |legend| legend.id != id }

        unless other_legends.count < MAX_LEGENDS_PER_LAYER
          errors.add(:layer, 'Maximum number of legends per layer reached')
        end
      end
    end

    def validate_definition_schema
      validator = Carto::LegendDefinitionValidator.new(type, definition)
      definition_errors = validator.errors

      if definition_errors.any?
        errors.add(:definition, definition_errors.join(', '))
      end
    end

    def force_notify_layer_change
      layer.force_notify_change
    end
  end
end
