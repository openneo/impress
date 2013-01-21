class Item
  module Search
    module Fields
      class SetField < Field
        def initialize(*args)
          super(*args)
          @values = {true => Set.new, false => Set.new}
        end
        
        def <<(filter)
          if @values[!filter.positive?].include?(filter.value)
            raise Item::Search::Contradiction,
                  "positive #{key} and negative #{key} both contain #{filter.value}"
          end
          
          @values[filter.positive?] << filter.value
        end
        
        def to_flex_params
          {
            :"_#{key}s" => nil_if_empty(@values[true]),
            :"_negative_#{key}s" => nil_if_empty(@values[false])
          }
        end
        
        private
        
        def nil_if_empty(set)
          set.map { |value| {key => value} } unless set.empty?
        end
      end
    end
  end
end
