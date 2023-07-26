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
            filters << (is_positive ?
              Filter.name_includes(value, locale) :
              Filter.name_excludes(value, locale))
          when 'is'
            case value
            when 'nc'
              filters << (is_positive ? Filter.is_nc : Filter.is_not_nc)
            when 'np'
              filters << (is_positive ? Filter.is_np : Filter.is_not_np)
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

    # A Filter is basically a wrapper for an Item scope, with extra info about
    # how to convert it into a search query string.
    class Filter
      def initialize(query, text)
        @query = query
        @text = text
      end

      def to_query
        @query
      end

      def to_s
        @text
      end

      def inspect
        "#<#{self.class.name} #{@text.inspect}>"
      end

      def self.name_includes(value, locale)
        text = /\s/.match(value) ? '"' + value + '"' : value
        self.new Item.name_includes(value, locale), text
      end

      def self.name_excludes(value, locale)
        text = '-' + (/\s/.match(value) ? '"' + value + '"' : value)
        self.new Item.name_excludes(value, locale), text
      end

      def self.is_nc
        self.new Item.is_nc, 'is:nc'
      end

      def self.is_not_nc
        self.new Item.is_np, '-is:nc'
      end

      def self.is_np
        self.new Item.is_np, 'is:np'
      end

      def self.is_not_np
        self.new Item.is_nc, '-is:np'
      end
    end
  end
end
