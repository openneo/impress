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
        key_str = @key.to_s
        if key_str.start_with?('is_')
          is_label = I18n.translate("items.search.flag_keywords.is")
          "#{sign}#{is_label}:#{label}"
        elsif key_str.start_with?('user_')
          user_label = I18n.translate("items.search.labels.user_closet_hanger_ownership")
          value = Query::REVERSE_RESOURCE_FINDERS[:ownership].call(@value)
          "#{sign}#{user_label}:#{value}"
        else
          if Query::TEXT_QUERY_RESOURCE_TYPES_BY_KEY.include?(@key)
            resource_type = Query::TEXT_QUERY_RESOURCE_TYPES_BY_KEY[@key]
            reverse_finder = Query::REVERSE_RESOURCE_FINDERS[resource_type]
            resource_value = reverse_finder.call(@value)
          else
            resource_value = @value
          end
          if resource_value.include?(' ')
            quoted_value = resource_value.inspect
          else
            quoted_value = resource_value
          end
          if @key == :name
            "#{sign}#{quoted_value}"
          else
            "#{sign}#{label}:#{quoted_value}"
          end
        end
      end

      private

      def label
        I18n.translate("items.search.labels.#{@key}").split(',').first
      end
    end
  end
end
