# encoding=utf-8
# ^ to put the regex in utf-8 mode

class Item
  module Search
    class Query
      def initialize(filters, user, text=nil)
        @filters = filters
        @user = user
        @text = text
      end
      
      def results
        @filters.map(&:to_query).inject(Item.all, &:merge).
          alphabetize_by_translations(Query.locale)
      end

      def to_s
        @text || @filters.map(&:to_s).join(' ')
      end

      def self.locale
        (I18n.fallbacks[I18n.locale] &
          I18n.locales_with_neopets_language_code).first
      end
      
      TEXT_FILTER_EXPR = /([+-]?)(?:(\p{Word}+):)?(?:"([^"]+)"|(\S+))/
      def self.from_text(text, user=nil)
        filters = []
        
        text.scan(TEXT_FILTER_EXPR) do |sign, key, quoted_value, unquoted_value|
          key = 'name' if key.blank?
          value = quoted_value || unquoted_value
          is_positive = (sign != '-')
          
          case key
          when 'name'
            filters << NameFilter.new(value, locale, is_positive)
          when 'is'
            case value
            when 'nc'
              filters << NCFilter.new(is_positive)
            when 'np'
              filters << NPFilter.new(is_positive)
            else
              message = I18n.translate('items.search.errors.not_found.label',
                :label => "is:#{value}")
              raise Item::Search::Error, message
            end
          else
            message = I18n.translate('items.search.errors.not_found.label',
              :label => key)
            raise Item::Search::Error, message
          end
        end
        
        self.new(filters, user, text)
      end

      def self.from_params(params, user=nil)
        raise NotImplementedError, "TODO: Reimplemented Advanced Search"
      end
    end

    class Error < Exception
    end

    private

    class NameFilter
      def initialize(value, locale, is_positive)
        @value = value
        @locale = locale
        @is_positive = is_positive
      end

      def to_query
        @is_positive ?
          Item.name_includes(@value, @locale) :
          Item.name_excludes(@value, @locale)
      end

      def to_s
        sign = @is_positive ? '' : '-'
        if /\s/.match(@value)
          sign + '"' + @value + '"'
        else
          sign + @value
        end
      end
    end

    class NCFilter
      def initialize(is_positive)
        @is_positive = is_positive
      end

      def to_query
        @is_positive ? Item.is_nc : Item.is_np
      end

      def to_s
        sign = @is_positive ? '' : '-'
        sign + 'is:nc'
      end
    end

    class NPFilter
      def initialize(is_positive)
        @is_positive = is_positive
      end

      def to_query
        @is_positive ? Item.is_np : Item.is_nc
      end

      def to_s
        sign = @is_positive ? '' : '-'
        sign + 'is:np'
      end
    end
  end
end
