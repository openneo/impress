class Item
  module Search
    class Filter
      attr_reader :key, :value
      
      def initialize(key, value, is_positive)
        @key = key
        @value = value
        @is_positive = is_positive
      end
      
      def positive?
        @is_positive
      end

      def to_s
        sign = positive? ? '' : '-'
        key_str = key.to_s
        if key_str.start_with?('is_')
          rest_of_key = key_str[3..-1]
          "#{sign}is:#{rest_of_key}"
        else
          quoted_value = value.include?(' ') ? value.inspect : value
          if key == :name
            "#{sign}#{quoted_value}"
          else
            "#{sign}#{key}:#{quoted_value}"
          end
        end
      end
    end
  end
end
