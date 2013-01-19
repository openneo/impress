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
    end
  end
end
