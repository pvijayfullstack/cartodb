# encoding utf-8

require_relative './definition'

module Carto
  class Form
    DEFAULT_FORMS_DEFINITION_LOCATION =
      "#{Rails.root}/lib/assets/javascripts/cartodb3/data/default-form-styles.json".freeze

    def initialize(geometry_type)
      @geometry_type = geometry_type

      unless style_class
        message = "Carto::Forms: No form for geometry type"
        CartoDB::Logger.error(message: message, geometry_type: geometry_type)

        raise "#{message}: '#{geometry_type}'"
      end
    end

    def to_hash
      return @hash if @hash

      merged_definition = forms_definition
      merged_definition.keys.each do |key|
        style_value = style_definition[key]

        merged_definition[key] = style_value if style_value
      end

      @hash = merged_definition
    end

    private

    def forms_definition
      @forms_definition ||= Carto::Definition.instance
                                             .load_from_file(DEFAULT_FORMS_DEFINITION_LOCATION)
    end

    def style_definition
      return @style_definition if @style_definition

      @style_definition = style.default_definition
    end

    def style_class
      @style_class ||= Carto::Styles::Style.style_for_geometry_type(@geometry_type)
    end

    def style
      @style ||= style_class.new
    end
  end
end
