class Item
  module Search
    class Field
      attr_reader :key
      
      def initialize(key)
        @key = key
      end
    end
  end
end
