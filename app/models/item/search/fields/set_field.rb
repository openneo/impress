class Item
  module Search
    module Fields
      class SetField < Field
        def initialize(*args)
          super(*args)
          @values = {true => Set.new, false => Set.new}
        end
        
        def <<(filter)
          if filter.value.respond_to?(:each)
            filter.value.each do |value|
              add_value(value, filter.positive?)
            end
          else
            add_value(filter.value, filter.positive?)
          end
        end
        
        def to_flex_params
          {
            key => nil_if_empty(@values[true]),
            :"negative_#{key}" => nil_if_empty(@values[false])
          }
        end
        
        private
        
        def add_value(value, is_positive)
          if @values[!is_positive].include?(value)
            raise Item::Search::Contradiction,
                  "positive #{key} and negative #{key} both contain #{value}"
          end
          
          @values[is_positive] << value
        end
        
        def nil_if_empty(set)
          set unless set.empty?
        end
      end
    end
  end
end
