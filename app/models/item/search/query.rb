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
          when 'occupies'
            filters << (is_positive ?
              Filter.occupies(value, locale) :
              Filter.not_occupies(value, locale))
          when 'restricts'
            filters << (is_positive ?
              Filter.restricts(value, locale) :
              Filter.not_restricts(value, locale))
          when 'fits'
            color_name, species_name = value.split('-')
            begin
              pet_type = PetType.matching_name(color_name, species_name, locale).first!
            rescue ActiveRecord::RecordNotFound
              message = I18n.translate('items.search.errors.not_found.pet_type',
                name1: color_name.capitalize, name2: species_name.capitalize)
              raise Item::Search::Error, message
            end
            filters << (is_positive ?
              Filter.fits(pet_type.body_id, color_name, species_name) :
              Filter.not_fits(pet_type.body_id, color_name, species_name))
          when 'user'
            if user.nil?
              message = I18n.translate('items.search.errors.not_logged_in')
              raise Item::Search::Error, message
            end
            case value
            when 'owns'
              filters << (is_positive ?
                Filter.user_owns(user) :
                Filter.user_wants(user))
            when 'wants'
            else
              message = I18n.translate('items.search.errors.not_found.ownership',
                keyword: value)
              raise Item::Search::Error, message
            end
          when 'is'
            case value
            when 'nc'
              filters << (is_positive ? Filter.is_nc : Filter.is_not_nc)
            when 'np'
              filters << (is_positive ? Filter.is_np : Filter.is_not_np)
            when 'pb'
              filters << (is_positive ? Filter.is_pb : Filter.is_not_pb)
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
      def initialize(query, text_fn)
        @query = query
        @text_fn = text_fn
      end

      def to_query
        @query
      end

      def to_s
        @text_fn.call
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

      def self.occupies(value, locale)
        self.new Item.occupies(value, locale), "occupies:#{value}"
      end

      def self.not_occupies(value, locale)
        self.new Item.not_occupies(value, locale), "-occupies:#{value}"
      end

      def self.restricts(value, locale)
        self.new Item.restricts(value, locale), "restricts:#{value}"
      end

      def self.not_restricts(value, locale)
        self.new Item.not_restricts(value, locale), "-restricts:#{value}"
      end

      def self.fits(body_id, color_name, species_name)
        # NOTE: Some color syntaxes are weird, like `fits:"polka dot-aisha"`!
        value = "#{color_name.downcase}-#{species_name.downcase}"
        value = '"' + value + '"' if value.include? ' '
        self.new Item.fits(body_id), "fits:#{value}"
      end

      def self.not_fits(body_id, color_name, species_name)
        # NOTE: Some color syntaxes are weird, like `fits:"polka dot-aisha"`!
        value = "#{color_name.downcase}-#{species_name.downcase}"
        value = '"' + value + '"' if value.include? ' '
        self.new Item.not_fits(body_id), "-fits:#{value}"
      end

      def self.user_owns(user)
        self.new user.owned_items, 'user:owns'
      end

      def self.user_wants(user)
        self.new user.wanted_items, 'user:wants'
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

      def self.is_pb
        self.new Item.is_pb, 'is:pb'
      end

      def self.is_not_pb
        self.new Item.is_not_pb, '-is:pb'
      end

      private

      def self.build_fits_filter_text(color_name, species_name)
        # NOTE: Colors like "Polka Dot" must be written as
        # `fits:"polka dot-aisha"`.
        value = "#{color_name.downcase}-#{species_name.downcase}"
        value = '"' + value + '"' if value.include? ' '
        "fits:#{value}"
      end
    end
  end
end
