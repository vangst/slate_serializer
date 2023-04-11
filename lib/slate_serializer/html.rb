require 'nokogiri'

module SlateSerializer
  # Html de- and serializer
  class Html
    # Default lookup list to convert html tags to object types
    ELEMENTS = {
      'a': 'link',
      'img': 'image',
      'li': 'listItem',
      'p': 'paragraph',
      'div': 'paragraph',
      'ol': 'orderedList',
      'ul': 'unorderedList',
      'table': 'table',
      'tbody': 'tbody',
      'tr': 'tr',
      'td': 'td',
      'text': 'text',
      'hr': 'hr',
      'figure': 'figure',
      'figcaption': 'figcaption'
    }.freeze
    # Default block types list
    BLOCK_ELEMENTS = %w[figure figcaption hr img li p ol ul table tbody tr td].freeze
    # Default inline types list
    INLINE_ELEMENTS = %w[a].freeze
    # Default mark types list
    MARK_ELEMENTS = {
      'em': 'italic',
      'strong': 'strong',
      'u': 'underline'
    }.freeze

    class << self
      # Convert html to a Slate document
      #
      # @param html format [String] the HTML
      # @param options [Hash]
      # @option options [Array] :elements Lookup list to convert html tags to object types
      # @option options [Array] :block_elemnts List of block types
      # @option options [Array] :inline_elemnts List of inline types
      # @option options [Array] :mark_elemnts List of mark types
      def deserializer(html, options = {})
        return empty_state if html.nil? || html == ''

        self.elements = options[:elements] || ELEMENTS
        self.block_elements = options[:block_elements] || BLOCK_ELEMENTS
        self.inline_elements = options[:inline_elements] || INLINE_ELEMENTS
        self.mark_elements = options[:mark_elements] || MARK_ELEMENTS

        html = html.gsub('<br>', "\n")
        Nokogiri::HTML.fragment(html).elements.map do |element|
          element_to_node(element)
        end
      end

      # Convert html to a Slate document
      #
      # @param value format [Hash] the Slate document
      # @return [String] plain text version of the Slate documnent
      def serializer(value)
        return '' unless value.is_a?(Array)

        value.map { |n| serialize_node(n) }.join
      end

      private

      attr_accessor :elements, :block_elements, :inline_elements, :mark_elements

      def element_to_node(element)
        type = convert_name_to_type(element)
        children = element.children.flat_map do |child|
          if block?(child)
            element_to_node(child)
          elsif inline?(child)
            element_to_inline(child)
          else
            next if child.text.strip == ''

            element_to_texts(child)
          end
        end.compact

        children << { text: '' } if children.empty? && type != 'image'

        node = {
          children: children,
          type: type
        }

        type.is_a?(Proc) ? type.call(node, element) : node
      end

      def element_to_inline(element)
        type = convert_name_to_type(element)
        nodes = element.children.flat_map do |child|
          element_to_texts(child)
        end

        {
          children: nodes,
          type: type
        }
      end

      def element_to_texts(element)
        nodes = []
        mark = convert_name_to_mark(element.name)

        if element.class == Nokogiri::XML::Element
          element.children.each do |child|
            nodes << element_to_text(child, mark)
          end
        else
          nodes << element_to_text(element)
        end

        nodes
      end

      def element_to_text(element, mark = nil)
        {
          text: element.text
        }.tap do |text|
          [mark, convert_name_to_mark(element.name)].compact.each do |m|
            text[m[:type].to_sym] = true
          end
        end
      end

      def convert_name_to_type(element)
        type = [element.name, element.attributes['type']&.value].compact.join
        elements[type.to_sym] || elements[:p]
      end

      def convert_name_to_mark(name)
        type = mark_elements[name.to_sym]

        return nil unless type

        {
          type: type
        }
      end

      def block?(element)
        block_elements.include?(element.name)
      end

      def inline?(element)
        inline_elements.include?(element.name)
      end

      def empty_state
        [
          {
            type: 'paragraph',
            children: [
              {
                text: ''
              }
            ]
          }
        ] 
      end

      def serialize_node(node)
        if node[:text]
          node[:text]
        else
          children = node[:children].map { |n| serialize_node(n) }.join 
          
          element = ELEMENTS.find { |_, v|  v == node[:type] }[0]
          
          if %i[ol].include?(element)
            element = :ol
          end

          "<#{element}>#{children}</#{element}>"
        end
      end
    end
  end
end
