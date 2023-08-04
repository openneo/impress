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
          when 'species'
            begin
              species = Species.matching_name(value, locale).first!
              color = Color.matching_name('blue', 'en').first!
              pet_type = PetType.where(color_id: color.id, species_id: species.id).first!
            rescue ActiveRecord::RecordNotFound
              message = I18n.translate('items.search.errors.not_found.species',
                species_name: species_name.capitalize)
              raise Item::Search::Error, message
            end
            filters << (is_positive ?
              Filter.fits_species(pet_type.body_id, value) :
              Filter.not_fits_species(pet_type.body_id, value))
          when 'user'
            if user.nil?
              message = I18n.translate('items.search.errors.not_logged_in')
              raise Item::Search::Error, message
            end
            case value
            when 'owns'
              filters << (is_positive ?
                Filter.owned_by(user) :
                Filter.not_owned_by(user))
            when 'wants'
              filters << (is_positive ?
                Filter.wanted_by(user) :
                Filter.not_wanted_by(user))
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
        filters = []

        params.values.each do |filter_params|
          key = filter_params[:key]
          value = filter_params[:value]
          is_positive = filter_params[:is_positive] != 'false'

          case filter_params[:key]
          when 'name'
            filters << (is_positive ?
              Filter.name_includes(value, locale) :
              Filter.name_excludes(value, locale))
          when 'is_nc'
            filters << (is_positive ? Filter.is_nc : Filter.is_not_nc)
          when 'occupied_zone_set_name'
            filters << (is_positive ?
              Filter.occupies(value, locale) :
              Filter.not_occupies(value, locale))
          when 'restricted_zone_set_name'
            filters << (is_positive ?
              Filter.restricts(value, locale) :
              Filter.not_restricts(value, locale))
          when 'fits_pet_type'
            pet_type = PetType.find(value)
            color_name = pet_type.color.name
            species_name = pet_type.species.name
            filters << (is_positive ?
              Filter.fits(pet_type.body_id, color_name, species_name) :
              Filter.not_fits(pet_type.body_id, color_name, species_name))
          when 'user_closet_hanger_ownership'
            case value
            when 'true'
              filters << (is_positive ?
                Filter.owned_by(user) :
                Filter.not_owned_by(user))
            when 'false'
              filters << (is_positive ?
                Filter.wanted_by(user) :
                Filter.not_wanted_by(user))
            end
          else
            Rails.logger.warn "Ignoring unexpected search filter key: #{key}"
          end
        end

        self.new(filters, user)
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
        self.new Item.name_includes(value, locale), "#{q value}"
      end

      def self.name_excludes(value, locale)
        self.new Item.name_excludes(value, locale), "-#{q value}"
      end

      def self.occupies(value, locale)
        self.new Item.occupies(value, locale), "occupies:#{q value}"
      end

      def self.not_occupies(value, locale)
        self.new Item.not_occupies(value, locale), "-occupies:#{q value}"
      end

      def self.restricts(value, locale)
        self.new Item.restricts(value, locale), "restricts:#{q value}"
      end

      def self.not_restricts(value, locale)
        self.new Item.not_restricts(value, locale), "-restricts:#{q value}"
      end

      def self.fits(body_id, color_name, species_name)
        # NOTE: Some color syntaxes are weird, like `fits:"polka dot-aisha"`!
        value = "#{color_name.downcase}-#{species_name.downcase}"
        self.new Item.fits(body_id), "fits:#{q value}"
      end

      def self.not_fits(body_id, color_name, species_name)
        # NOTE: Some color syntaxes are weird, like `fits:"polka dot-aisha"`!
        value = "#{color_name.downcase}-#{species_name.downcase}"
        self.new Item.not_fits(body_id), "-fits:#{q value}"
      end

      def self.fits_species(body_id, species_name)
        self.new Item.fits(body_id), "species:#{q species_name}"
      end
      
      def self.not_fits_species(body_id, species_name)
        self.new Item.not_fits(body_id), "-species:#{q species_name}"
      end

      def self.owned_by(user)
        self.new user.owned_items, 'user:owns'
      end

      def self.not_owned_by(user)
        self.new user.unowned_items, 'user:owns'
      end

      def self.wanted_by(user)
        self.new user.wanted_items, 'user:wants'
      end

      def self.not_wanted_by(user)
        self.new user.unwanted_items, 'user:wants'
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

      # Add quotes around the value, if needed.
      def self.q(value)
        /\s/.match(value) ? '"' + value + '"' : value
      end

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
