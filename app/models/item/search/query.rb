class Item
  module Search
    class Query
      FIELD_CLASSES = {
        :is_nc => Fields::Flag,
        :is_pb => Fields::Flag,
        :species_support_id => Fields::SetField,
        :occupied_zone_id => Fields::SetField,
        :restricted_zone_id => Fields::SetField,
        :name => Fields::SetField,
        :user_closet_hanger_ownership => Fields::SetField
      }
      
      def initialize(filters, user)
        @filters = filters
        @user = user
      end
      
      def fields
        initial_fields.tap do |fields|
          @filters.each { |filter| fields[filter.key] << filter }
        end
      end
      
      def to_flex_params
        fields.values.map(&:to_flex_params).inject(&:merge)
      end
      
      def paginate(options={})
        begin
          flex_params = self.to_flex_params
        rescue Item::Search::Contradiction
          # If we have a contradictory query, no need to raise a stink about
          # it, but no need to actually run a search, either.
          return []
        end
        
        final_flex_params = {
          :page => (options[:page] || 1),
          :size => (options[:per_page] || 30),
          :type => 'item'
        }.merge(flex_params)
        
        locales = I18n.fallbacks[I18n.locale] &
          I18n.locales_with_neopets_language_code
        final_flex_params[:locale] = locales.first
        
        # Extend the names/negative_names queries with the corresponding
        # localalized field names.
        if final_flex_params[:_names] || final_flex_params[:_negative_names]
          locale_entries = locales.map do |locale|
            boost = (locale == I18n.locale) ? 4 : 1
            "name.#{locale}^#{boost}"
          end
          
          # We *could* have set _name_locales once as a partial, but Flex won't
          # let us call partials from inside other partials. Whatever. Assign
          # it to each name entry instead. I also feel bad doing this
          # afterwards, since it's kinda the field's job to return proper flex
          # params, but that's a refactor for another day.
          [:_names, :_negative_names].each do |key|
            if final_flex_params[key]
              final_flex_params[key].each do |name_query|
                name_query[:fields] = locale_entries
              end
            end
          end
        end
        
        # Okay, yeah, looks like this really does deserve a refactor, like
        # _names and _negative_names do. (Or Flex could just make all variables
        # accessible from partials... hint, hint)
        [:_user_closet_hanger_ownerships, :_negative_user_closet_hanger_ownerships].each do |key|
          if final_flex_params[key]
            Item::Search.error 'not_logged_in' unless @user
            
            final_flex_params[key].each do |entry|
              entry[:user_id] = @user.id
            end
          end
        end
        
        result = FlexSearch.item_search(final_flex_params)
        result.scoped_loaded_collection(
          :scopes => {'Item' => Item.includes(:translations)}
        )
      end
      
      # Load the text query labels from I18n, so that when we see, say,
      # the filter "species:acara", we know it means species_support_id.
      TEXT_KEYS_BY_LABEL = {}
      OWNERSHIP_KEYWORDS = {}
      I18n.available_locales.each do |locale|
        TEXT_KEYS_BY_LABEL[locale] = {}
        OWNERSHIP_KEYWORDS[locale] = {}
        FIELD_CLASSES.keys.each do |key|
          # A locale can specify multiple labels for a key by separating by
          # commas: "occupies,zone,type"
          labels = I18n.translate("items.search.labels.#{key}",
                                  :locale => locale).split(',')
          labels.each { |label| TEXT_KEYS_BY_LABEL[locale][label] = key }
          
          {:owns => true, :wants => false}.each do |key, value|
            translated_key = I18n.translate("items.search.labels.user_#{key}",
                                            :locale => locale)
            OWNERSHIP_KEYWORDS[locale][translated_key] = value
          end
        end
      end
      
      TEXT_QUERY_RESOURCE_FINDERS = {
        :species => lambda { |name|
          species = Species.find_by_name(name)
          unless species
            Item::Search.error 'not_found.species', :species_name => name
          end
          species.id
        },
        :zone => lambda { |label|
          zone_set = Zone.with_plain_label(label)
          if zone_set.empty?
            Item::Search.error 'not_found.zone', :zone_name => label
          end
          zone_set.map(&:id)
        },
        :ownership => lambda { |keyword|
          OWNERSHIP_KEYWORDS[I18n.locale][keyword].tap do |value|
            if value.nil?
              Item::Search.error 'not_found.ownership', :keyword => keyword
            end
          end
        }
      }
      
      TEXT_QUERY_RESOURCE_TYPES_BY_KEY = {
        :species_support_id => :species,
        :occupied_zone_id => :zone,
        :restricted_zone_id => :zone,
        :user_closet_hanger_ownership => :ownership
      }
      
      TEXT_FILTER_EXPR = /([+-]?)(?:([a-z]+):)?(?:"([^"]+)"|(\S+))/
      def self.from_text(text, user=nil)
        filters = []
        
        is_keyword = I18n.translate('items.search.flag_keywords.is')
        text.scan(TEXT_FILTER_EXPR) do |sign, label, quoted_value, unquoted_value|
          label ||= 'name'
          raw_value = quoted_value || unquoted_value
          is_positive = (sign != '-')
          
          if label == is_keyword
            # is-filters are weird. "-is:nc" is transposed to something more
            # like "-nc:<nil>", then it's translated into a negative "is_nc"
            # flag. Fun fact: "nc:foobar" and "-nc:foobar" also work. A bonus,
            # I guess. There's probably a good way to refactor this to avoid
            # the unintended bonus syntax, but this is a darn good cheap
            # technique for the time being.
            label = raw_value
            raw_value = nil
          end
          
          key = TEXT_KEYS_BY_LABEL[I18n.locale][label]
          if key.nil?
            message = I18n.translate('items.search.errors.not_found.label',
                                     :label => label)
            raise Item::Search::Error, message
          end
          
          if TEXT_QUERY_RESOURCE_TYPES_BY_KEY.has_key?(key)
            resource_type = TEXT_QUERY_RESOURCE_TYPES_BY_KEY[key]
            finder = TEXT_QUERY_RESOURCE_FINDERS[resource_type]
            value = finder.call(raw_value)
          else
            value = raw_value
          end
          
          filters << Filter.new(key, value, is_positive)
        end
        
        self.new(filters, user)
      end
      
      private
      
      # The fields start out empty, then have the filters inserted into 'em,
      # so that the fields can validate and aggregate their requirements.
      def initial_fields
        {}.tap do |fields|
          FIELD_CLASSES.map do |key, klass|
            fields[key] = klass.new(key)
          end
        end
      end
    end
  end
end