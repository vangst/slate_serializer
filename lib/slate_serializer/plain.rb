module SlateSerializer
  # Text  de- and serializer
  class Plain
    class << self
      # Convert text to a Slate document
      #
      # @param text format [String] the text
      # return [Hash] Slate document
      def deserializer(text)
        text = '' if text.nil?

        lines = split_text_into_lines(text)
        convert_lines_into_nodes(lines)
      end

      # Convert a Slate Document to plain text
      #
      # @param value format [Hash] the Slate document
      # @param options format [Hash] options for the serializer, delimitter defaults to "\n"
      # @return [String] plain text version of the Slate documnent
      def serializer(value, options = {})
        return '' unless value.is_a?(Array)

        options[:delimiter] = "\n" unless options.key?(:delimiter)

        value.map { |n| serialize_node(n, options) }.join(options[:delimiter])
      end

      private

      def split_text_into_lines(text)
        lines = text.strip.split("\n").map(&:strip)
        blocks = []

        loop do
          index = lines.find_index('')
          if index.nil?
            blocks << lines.join("\n")
            break
          end

          blocks << lines[0...index].join("\n")
          lines.shift(index + 1)
        end

        blocks.length == 1 ? blocks : blocks.reject { |block| block == '' }
      end

      def convert_lines_into_nodes(lines)
        lines.map do |line|
          {
            type: 'paragraph',
            children: [
              text: line
            ]
          }
        end
      end

      def serialize_node(node, options)
        if node[:text]
          node[:text]
        else
          node[:children].map { |n| serialize_node(n, options) }.join(options[:delimiter])          
        end
      end
    end
  end
end
