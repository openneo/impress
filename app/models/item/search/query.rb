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
        @filters.map(&:to_query).inject(Item.all, &:merge).order(:name)
      end

      def to_s
        @text || @filters.map(&:to_s).join(' ')
      end
      
      TEXT_FILTER_EXPR = /([+-]?)(?:(\p{Word}+):)?(?:"([^"]+)"|(\S+))/
      def self.from_text(text, user=nil)
        filters = []
        
        text.scan(TEXT_FILTER_EXPR) do |sign, key, quoted_value, unquoted_value|
          key = 'name' if key.blank?
          value = quoted_value || unquoted_value
          is_positive = (sign != '-')
          
          filter = parse_text_filter(key, value, is_positive)
          filters << filter if filter.present?
        end
        
        self.new(filters, user, text)
      end

      def self.from_params(params, user=nil)
        filters = []

        params.values.each do |filter_params|
          key = filter_params[:key]
          value = filter_params[:value]
          is_positive = filter_params[:is_positive] != 'false'

          filter = parse_params_filter(key, value, is_positive)
          filters << filter if filter.present?
        end

        self.new(filters, user)
      end

      private

      def self.parse_text_filter(key, value, is_positive)
        case key
        when 'name'
          is_positive ?
            Filter.name_includes(value) :
            Filter.name_excludes(value)
        when 'occupies'
          is_positive ? Filter.occupies(value) : Filter.not_occupies(value)
        when 'restricts'
          is_positive ? Filter.restricts(value) : Filter.not_restricts(value)
        when 'fits'
          color_name, species_name = value.split("-")
          pet_type = load_pet_type_by_name(color_name, species_name)
          is_positive ?
            Filter.fits_pet_type(pet_type, color_name:, species_name:) :
            Filter.not_fits_pet_type(pet_type, color_name:, species_name:)
        when 'species'
          begin
            species = Species.find_by_name!(value)
            color = Color.find_by_name!('blue')
            pet_type = PetType.where(color_id: color.id, species_id: species.id).first!
          rescue ActiveRecord::RecordNotFound
            message = I18n.translate('items.search.errors.not_found.species',
              species_name: value.capitalize)
            raise Item::Search::Error, message
          end
          is_positive ?
            Filter.fits_species(pet_type.body_id, value) :
            Filter.not_fits_species(pet_type.body_id, value)
        when 'user'
          if user.nil?
            message = I18n.translate('items.search.errors.not_logged_in')
            raise Item::Search::Error, message
          end
          case value
          when 'owns'
            is_positive ? Filter.owned_by(user) : Filter.not_owned_by(user)
          when 'wants'
            is_positive ? Filter.wanted_by(user) : Filter.not_wanted_by(user)
          else
            message = I18n.translate('items.search.errors.not_found.ownership',
              keyword: value)
            raise Item::Search::Error, message
          end
        when 'is'
          case value
          when 'nc'
            is_positive ? Filter.is_nc : Filter.is_not_nc
          when 'np'
            is_positive ? Filter.is_np : Filter.is_not_np
          when 'pb'
            is_positive ? Filter.is_pb : Filter.is_not_pb
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

      def self.parse_params_filter(key, value, is_positive)
        case key
        when 'name'
          is_positive ?
            Filter.name_includes(value) :
            Filter.name_excludes(value)
        when 'is_nc'
          is_positive ? Filter.is_nc : Filter.is_not_nc
        when 'is_pb'
          is_positive ? Filter.is_pb : Filter.is_not_pb
        when 'is_np'
          is_positive ? Filter.is_np : Filter.is_not_np
        when 'occupied_zone_set_name'
          is_positive ? Filter.occupies(value) : Filter.not_occupies(value)
        when 'restricted_zone_set_name'
          is_positive ? Filter.restricts(value) : Filter.not_restricts(value)
        when 'fits'
          if value[:alt_style_id].present?
            alt_style = load_alt_style_by_id(value[:alt_style_id])
            is_positive ?
              Filter.fits_alt_style(alt_style) :
              Filter.fits_alt_style(alt_style)
          else
            pet_type = load_pet_type_by_color_and_species(
              value[:color_id], value[:species_id])
            is_positive ?
              Filter.fits_pet_type(pet_type) :
              Filter.not_fits_pet_type(pet_type)
          end
        when 'user_closet_hanger_ownership'
          case value
          when 'true'
            is_positive ?
              Filter.owned_by(user) :
              Filter.not_owned_by(user)
          when 'false'
            is_positive ?
              Filter.wanted_by(user) :
              Filter.not_wanted_by(user)
          end
        else
          Rails.logger.warn "Ignoring unexpected search filter key: #{key}"
        end
      end

      def self.load_pet_type_by_name(color_name, species_name)
        begin
          PetType.matching_name(color_name, species_name).first!
        rescue ActiveRecord::RecordNotFound
          message = I18n.translate('items.search.errors.not_found.pet_type',
            name1: color_name.capitalize, name2: species_name.capitalize)
          raise Item::Search::Error, message
        end
      end

      def self.load_pet_type_by_color_and_species(color_id, species_id)
        begin
          PetType.where(color_id: color_id, species_id: species_id).first!
        rescue ActiveRecord::RecordNotFound
          color_name = Color.find(color_id).name rescue "Color #{color_id}"
          species_name = Species.find(species_id).name rescue "Species #{species_id}"
          message = I18n.translate('items.search.errors.not_found.pet_type',
            name1: color_name.capitalize, name2: species_name.capitalize)
          raise Item::Search::Error, message
        end
      end

      def self.load_alt_style_by_id(alt_style_id)
        begin
          AltStyle.find(alt_style_id)
        rescue
          message = I18n.translate('items.search.errors.not_found.alt_style',
            filter_text: "alt-style-#{alt_style_id}")
          raise Item::Search::Error, message
        end
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

      def self.name_includes(value)
        self.new Item.name_includes(value), "#{q value}"
      end

      def self.name_excludes(value)
        self.new Item.name_excludes(value), "-#{q value}"
      end

      def self.occupies(value)
        self.new Item.occupies(value), "occupies:#{q value}"
      end

      def self.not_occupies(value)
        self.new Item.not_occupies(value), "-occupies:#{q value}"
      end

      def self.restricts(value)
        self.new Item.restricts(value), "restricts:#{q value}"
      end

      def self.not_restricts(value)
        self.new Item.not_restricts(value), "-restricts:#{q value}"
      end

      def self.fits_pet_type(pet_type, color_name: nil, species_name: nil)
        value = pet_type_to_filter_text(pet_type, color_name:, species_name:)
        self.new Item.fits(pet_type.body_id), "fits:#{q value}"
      end

      def self.not_fits_pet_type(pet_type, color_name: nil, species_name: nil)
        value = pet_type_to_filter_text(pet_type, color_name:, species_name:)
        self.new Item.not_fits(pet_type.body_id), "-fits:#{q value}"
      end

      def self.fits_alt_style(alt_style)
        value = alt_style_to_filter_text(alt_style)
        self.new Item.fits(alt_style.body_id), "fits:#{q value}"
      end

      def self.not_fits_alt_style(alt_style)
        value = alt_style_to_filter_text(alt_style)
        self.new Item.not_fits(alt_style.body_id), "-fits:#{q value}"
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
        self.new Item.is_not_nc, '-is:nc'
      end

      def self.is_np
        self.new Item.is_np, 'is:np'
      end

      def self.is_not_np
        self.new Item.is_not_np, '-is:np'
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

      def self.pet_type_to_filter_text(pet_type, color_name: nil, species_name: nil)
        # Load the color & species name if needed, or use them from the params
        # if already known (e.g. from parsing a "fits:blue-acara" text query).
        color_name ||= pet_type.color.name
        species_name ||= pet_type.species.name

        # NOTE: Some color syntaxes are weird, like `fits:"polka dot-aisha"`!
        "#{color_name}-#{species_name}".downcase
      end

      def self.alt_style_to_filter_text(alt_style)
        "alt-style-#{alt_style.id}"
      end
    end
  end
end
