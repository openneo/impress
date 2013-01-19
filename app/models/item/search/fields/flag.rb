class Item
  module Search
    module Fields
      class Flag < Field
        def <<(filter)
          if @value.nil?
            @value = filter.positive?
          elsif @value != filter.positive?
            raise Item::Search::Contradiction,
                  "flag #{key} both positive and negative"
          end
        end
        
        def to_flex_params
          {key => @value}
        end
      end
    end
  end
end
