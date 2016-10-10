# encoding utf-8

module Carto
  class LegendMigrator
    attr_reader :layer_id, :legend

    def initialize(layer_id, legend)
      @layer_id = layer_id
      @legend = legend
    end

    def build
      new_type, new_definition = type_and_definition
      title = title if title.present? && legend['show_title']

      Legend.new(layer_id: layer_id,
                 title: title,
                 type: new_type,
                 definition: new_definition)
    end

    private

    def type
      @type ||= legend['type']
    end

    def items
      @items ||= legend['items']
    end

    def title
      legend['title']
    end

    HTML_RAMP_TYPES = %w(choropleth intensity density).freeze
    CUSTOM_TYPES = %w(category custom).freeze

    def type_and_definition
      if HTML_RAMP_TYPES.include?(type)
        ['html', build_html_definition_from_ramp_type]
      elsif CUSTOM_TYPES.include?(type)
        ['custom', build_custom_definition_from_custom_type]
      elsif type == 'bubble'
        ['html', build_html_definition_from_bubble]
      else
        [nil, nil]
      end
    end

    COLOR_REGEXP = /^#(?:[0-9a-fA-F]{3}){1,2}$/

    def build_custom_definition_from_custom_type
      categories = items.each_with_index.map do |item, index|
        title = item['name'].to_s || "Category #{index + 1}"
        color = item['value']

        category_definition = { title: title }

        if color && color =~ COLOR_REGEXP
          category_definition[:color] = color
        end

        category_definition
      end

      { categories: categories }
    end

    def build_html_definition_from_ramp_type
      left_label, right_label = labels_for_items
      style = style_for_gradient

      html =  %(<div class="u-flex u-justifySpace u-bSpace--m">\n)
      html += %(  <p class="CDB-Text CDB-Size-small">#{left_label}</p>\n)
      html += %(  <p class="CDB-Text CDB-Size-small">#{right_label}</p>\n)
      html += %(</div>\n)
      html += %(<div class="Legend-choropleth" style="#{style}"></div>\n)

      { html: html }
    end

    def style_for_gradient
      first_color_index = labels_for_items.compact.count
      item_colors = items[first_color_index..-1].map do |item|
        color = item['value'].downcase

        color if color =~ COLOR_REGEXP
      end

      compact_item_colors = item_colors.compact
      if compact_item_colors.count == 1
        item_colors << generate_end_color(item_colors.first)
      end

      gradient_stops = compact_item_colors.join(', ')
      "background: linear-gradient(90deg, #{gradient_stops})"
    end

    def build_html_definition_from_bubble(steps: 6)
      left, right = labels_for_items
      heights, values = heights_and_values(left, right, steps)

      html =  %(<div class="Bubble-container u-flex u-justifySpace">\n)
      html += %(  <ul class="Bubble-numbers u-flex u-justifySpace">\n)
      values.reverse.each_with_index do |value, index|
        html += %(    <li class="Bubble-numbersItem CDB-Text CDB-Size-small" style="bottom: #{heights[index]}%">#{value}</li></li>\n)
      end
      html += %(  </ul>\n)
      html += %(  <div class="Bubble-inner">\n)
      html += %(    <ul class="Bubble-list">\n)
      heights[0..-2].each do |height|
        html += %(      <li class="js-bubbleItem Bubble-item Bubble-item—-01" style="height: #{height}%; width: #{height}%">\n)
        html += %(        <span class="Bubble-itemCircle" style="background-color: #{items.last['value']}"></span>\n)
        html += %(      </li>\n)
      end
      html += %(    </ul>\n)
      html += %(  </div>\n)
      html += %(</div>\n)

      { html: html }
    end

    def heights_and_values(min, max, steps)
      step = (max - min) / (steps - 1)
      values = Array.new(steps) do |index|
        formatted_string_number(min + (index  * step))
      end

      heights = Array.new(steps) do |index|
        100 - (index * 100 / (steps - 1))
      end

      [heights, values]
    end

    def labels_for_items
      return @labels_for_items if @labels_for_items

      first_item = items.first
      second_item = items.second

      if first_item && first_item['type'] == 'text'
        left_label = first_item['value']
      end

      if second_item && second_item['type'] == 'text'
        right_label = second_item['value']
      end

      @labels_for_items = [left_label, right_label]
      @labels_for_items
    end

    def generate_end_color(start_color, brighten_steps: 4)
      start_red, start_green, start_blue = html_color_to_rgb(start_color)

      brightened_red = start_red
      brightened_green = start_green
      brightened_blue = start_blue
      brighten_steps.times do
        brightened_red = (brightened_red * start_red / 255)
        brightened_green = (brightened_green * start_green / 255)
        brightened_blue = (brightened_blue * start_blue / 255)
      end

      hex_red = brightened_red.to_s(16)
      hex_green = brightened_green.to_s(16)
      hex_blue = brightened_blue.to_s(16)

      if hex_red.length == 1
        hex_red = [hex_red, hex_red].join
      end

      if hex_green.length == 1
        hex_green = [hex_green, hex_green].join
      end

      if hex_blue.length == 1
        hex_blue = [hex_blue, hex_blue].join
      end

      "##{hex_red}#{hex_green}#{hex_blue}"
    end

    def html_color_to_rgb(html_color)
      stripped = html_color.delete('#')

      if stripped.length == 3
        characters = stripped.map { |character| [character, character] }
        stripped = characters.flatten.join
      end

      [stripped[0..1].hex, stripped[2..3].hex, stripped[4..5].hex]
    end

    def formatted_string_number(number)
      if number < 1_000
        pretty_round(number).to_s
      elsif number < 1_000_000
        "#{pretty_round(number / 1_000)}K"
      else
        "#{pretty_round(number / 1_000_000)}M"
      end
    end

    def pretty_round(number)
      integer = number.to_i
      rounded = number.round(1)

      integer == rounded ? integer : rounded
    end
  end
end
