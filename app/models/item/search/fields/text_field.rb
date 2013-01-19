class Item
  module Search
    module Fields
      class TextField < Field
        def initialize(*args)
          super(*args)
          @values = {true => '', false => ''}
        end
        
        def <<(filter)
          @values[filter.positive?] << (filter.value + ' ')
        end
        
        def to_flex_params
          {
            key => nil_if_empty(@values[true]),
            :"negative_#{key}" => nil_if_empty(@values[false])
          }
        end
        
        private
        
        def nil_if_empty(str)
          str unless str.empty?
        end
      end
    end
  end
end
