class Item < ActiveRecord::Base
  include Flex::Model
  include PrettyParam
  
  set_inheritance_column 'inheritance_type' # PHP Impress used "type" to describe category

  SwfAssetType = 'object'
  
  translates :name, :description, :rarity

  has_many :closet_hangers
  has_one :contribution, :as => :contributed
  has_many :parent_swf_asset_relationships, :as => :parent
  has_many :swf_assets, :through => :parent_swf_asset_relationships

  attr_writer :current_body_id, :owned, :wanted

  NCRarities = [0, 500]
  PAINTBRUSH_SET_DESCRIPTION = 'This item is part of a deluxe paint brush set!'
  SPECIAL_COLOR_DESCRIPTION_REGEX =
    /This item is only wearable by Neopets painted ([a-zA-Z]+)\.|WARNING: This [a-zA-Z]+ can be worn by ([a-zA-Z]+) [a-zA-Z]+ ONLY!/

  cattr_reader :per_page
  @@per_page = 30

  scope :alphabetize, order(arel_table[:name])
  scope :alphabetize_by_translations, lambda {
    it = Item::Translation.arel_table
    order(it[:name])
  }

  scope :join_swf_assets, joins(:swf_assets).group(arel_table[:id])

  scope :newest, order(arel_table[:created_at].desc) if arel_table[:created_at]

  scope :spidered_longest_ago, order(["(last_spidered IS NULL) DESC", "last_spidered DESC"])

  scope :sold_in_mall, where(:sold_in_mall => true)
  scope :not_sold_in_mall, where(:sold_in_mall => false)

  scope :sitemap, select([arel_table[:id], arel_table[:name]]).
                  order(arel_table[:id]).limit(49999)

  scope :with_closet_hangers, joins(:closet_hangers)
  
  flex.sync self
  
  def flex_source
    indexed_attributes = {
      :is_nc => self.nc?,
      :is_pb => self.pb?,
      :species_support_id => self.species_support_ids,
      :occupied_zone_id => self.occupied_zone_ids,
      :restricted_zone_id => self.restricted_zone_ids,
      :name => {}
    }
    
    I18n.usable_locales_with_neopets_language_code.each do |locale|
      I18n.with_locale(locale) do
        indexed_attributes[:name][locale] = self.name
      end
    end
    
    indexed_attributes.to_json
  end

  def closeted?
    @owned || @wanted
  end
  
  # Return an OrderedHash mapping users to the number of times they
  # contributed to this item's assets, from most contributions to least.
  def contributors_with_counts
    # Get contributing users' IDs
    swf_asset_ids = swf_assets.select(SwfAsset.arel_table[:id]).map(&:id)
    swf_asset_contributions = Contribution.select('user_id').
      where(:contributed_type => 'SwfAsset', :contributed_id => swf_asset_ids)
    contributor_ids = swf_asset_contributions.map(&:user_id)
    
    # Get the users, mapped by ID
    contributors_by_id = {}
    User.find(contributor_ids).each { |u| contributors_by_id[u.id] = u }
    
    # Count each user's contributions
    contributor_counts_by_id = Hash.new(0)
    contributor_ids.each { |id| contributor_counts_by_id[id] += 1 }
    
    # Build an OrderedHash mapping users to counts in descending order
    contributors_with_counts = ActiveSupport::OrderedHash.new
    contributor_counts_by_id.sort_by { |k, v| v }.reverse.each do |id, count|
      contributor = contributors_by_id[id]
      contributors_with_counts[contributor] = count
    end
    contributors_with_counts
  end

  def nc?
    NCRarities.include?(rarity_index)
  end
  
  def pb?
    (self.description == PAINTBRUSH_SET_DESCRIPTION)
  end

  def owned?
    @owned
  end

  def wanted?
    @wanted
  end

  def restricted_zones
    unless @restricted_zones
      @restricted_zones = []
      zones_restrict.split(//).each_with_index do |switch, id|
        @restricted_zones << Zone.find(id.to_i + 1) if switch == '1'
      end
    end
    @restricted_zones
  end
  
  def restricted_zone_ids
    restricted_zones.map(&:id)
  end
  
  def occupied_zone_ids
    occupied_zones.map(&:id)
  end

  def occupied_zones
    all_body_ids = []
    zone_body_ids = {}
    selected_assets = swf_assets.select('body_id, zone_id').each do |swf_asset|
      zone_body_ids[swf_asset.zone_id] ||= []
      body_ids = zone_body_ids[swf_asset.zone_id]
      body_ids << swf_asset.body_id unless body_ids.include?(swf_asset.body_id)
      all_body_ids << swf_asset.body_id unless all_body_ids.include?(swf_asset.body_id)
    end
    zones = []
    total_body_ids = all_body_ids.size
    zone_body_ids.each do |zone_id, body_ids|
      zone = Zone.find(zone_id)
      zone.sometimes = true if body_ids.size < total_body_ids
      zones << zone
    end
    zones
  end

  def affected_zones
    restricted_zones + occupied_zones
  end

  def special_color
    @special_color ||= determine_special_color
  end

  protected
  def determine_special_color
    I18n.with_locale(I18n.default_locale) do
      # Rather than go find the special description in all locales, let's just
      # run this logic in English.
      if description.include?(PAINTBRUSH_SET_DESCRIPTION)
        downcased_name = name.downcase
        Color.nonstandard.each do |color|
          return color if downcased_name.include?(color.name)
        end
      end

      match = description.match(SPECIAL_COLOR_DESCRIPTION_REGEX)
      if match
        color = match[1] || match[2]
        return Color.find_by_name(color.downcase)
      end
    end
  end
  public

  def species_support_ids
    @species_support_ids_array ||= read_attribute('species_support_ids').split(',').map(&:to_i) rescue nil
  end

  def species_support_ids=(replacement)
    @species_support_ids_array = nil
    replacement = replacement.join(',') if replacement.is_a?(Array)
    write_attribute('species_support_ids', replacement)
  end

  def supported_species
    body_ids = swf_assets.select([:body_id]).map(&:body_id)
    return Species.all if body_ids.include?(0)
    
    pet_types = PetType.where(:body_id => body_ids).select([:species_id])
    species_ids = pet_types.map(&:species_id).uniq
    Species.find(species_ids)
  end
  
  def support_species?(species)
    species_support_ids.blank? || species_support_ids.include?(species.id)
  end

  def as_json(options = {})
    {
      :description => description,
      :id => id,
      :name => name,
      :thumbnail_url => thumbnail_url,
      :zones_restrict => zones_restrict,
      :rarity_index => rarity_index,
      :owned => owned?,
      :wanted => wanted?,
      :nc => nc?
    }
  end

  before_create do
    self.sold_in_mall ||= false
    true
  end

  def handle_assets!
    if @parent_swf_asset_relationships_to_update && @current_body_id
      new_swf_asset_ids = @parent_swf_asset_relationships_to_update.map(&:swf_asset_id)
      rels = ParentSwfAssetRelationship.arel_table
      swf_assets = SwfAsset.arel_table
      
      # If a relationship used to bind an item and asset for this body type,
      # but doesn't in this sample, the two have been unbound. Delete the
      # relationship.
      ids_to_delete = self.parent_swf_asset_relationships.
        select(rels[:id]).
        joins(:swf_asset).
        where(rels[:swf_asset_id].not_in(new_swf_asset_ids)).
        where(swf_assets[:body_id].in([@current_body_id, 0])).
        map(&:id)
      
      unless ids_to_delete.empty?
        ParentSwfAssetRelationship.where(:id => ids_to_delete).delete_all
      end
      
      @parent_swf_asset_relationships_to_update.each do |rel|
        rel.save!
        rel.swf_asset.save!
      end
    end
  end
  
  def body_specific?
    # If there are species support IDs (it's not empty), the item is
    # body-specific. If it's empty, it fits everyone the same.
    !species_support_ids.empty?
  end

  def origin_registry_info=(info)
    # bear in mind that numbers from registries are floats
    self.species_support_ids = info[:species_support].map(&:to_i)
    attribute_names.each do |attribute|
      value = info[attribute.to_sym]
      if value
        value = value.to_i if value.is_a? Float
        self[attribute] = value
      end
    end
  end

  def pending_swf_assets
    @parent_swf_asset_relationships_to_update.inject([]) do |all_swf_assets, relationship|
      all_swf_assets << relationship.swf_asset
    end
  end

  def parent_swf_asset_relationships_to_update=(rels)
    @parent_swf_asset_relationships_to_update = rels
  end
  
  def needed_translations
    translatable_locales = Set.new(I18n.locales_with_neopets_language_code)
    translated_locales = Set.new(translations.map(&:locale))
    translatable_locales - translated_locales
  end

  def self.all_by_ids_or_children(ids, swf_assets)
    swf_asset_ids = []
    swf_assets_by_id = {}
    swf_assets_by_parent_id = {}
    swf_assets.each do |swf_asset|
      id = swf_asset.id
      swf_assets_by_id[id] = swf_asset
      swf_asset_ids << id
    end
    SwfAsset.select([
        SwfAsset.arel_table[:id],
        ParentSwfAssetRelationship.arel_table[:parent_id]
      ]).object_assets.joins(:parent_swf_asset_relationships).
      where(SwfAsset.arel_table[:id].in(swf_asset_ids)).each do |row|
        item_id = row.parent_id.to_i
        swf_assets_by_parent_id[item_id] ||= []
        swf_assets_by_parent_id[item_id] << swf_assets_by_id[row.id.to_i]
        ids << item_id
      end
    find(ids).tap do |items|
      items.each do |item|
        swf_assets = swf_assets_by_parent_id[item.id]
        if swf_assets
          swf_assets.each do |swf_asset|
            swf_asset.item = item
          end
        end
      end
    end
  end

  def self.collection_from_pet_type_and_registries(pet_type, info_registry, asset_registry, scope=Item.scoped)
    # bear in mind that registries are arrays with many nil elements,
    # due to how the parser works

    # Collect existing items
    items = {}
    item_ids = []
    info_registry.each do |item_id, info|
      if info && info[:is_compatible]
        item_ids << item_id.to_i
      end
    end

    # Collect existing relationships
    existing_relationships_by_item_id_and_swf_asset_id = {}
    existing_items = scope.find_all_by_id(item_ids, :include => :parent_swf_asset_relationships)
    existing_items.each do |item|
      items[item.id] = item
      relationships_by_swf_asset_id = {}
      item.parent_swf_asset_relationships.each do |relationship|
        relationships_by_swf_asset_id[relationship.swf_asset_id] = relationship
      end
      existing_relationships_by_item_id_and_swf_asset_id[item.id] =
        relationships_by_swf_asset_id
    end

    # Collect existing assets
    swf_asset_ids = []
    asset_registry.each do |asset_id, asset_data|
      swf_asset_ids << asset_id.to_i if asset_data
    end
    existing_swf_assets = SwfAsset.object_assets.find_all_by_remote_id swf_asset_ids
    existing_swf_assets_by_remote_id = {}
    existing_swf_assets.each do |swf_asset|
      existing_swf_assets_by_remote_id[swf_asset.remote_id] = swf_asset
    end

    # With each asset in the registry,
    relationships_by_item_id = {}
    asset_registry.each do |asset_id, asset_data|
      if asset_data
        # Build and update the item
        item_id = asset_data[:obj_info_id].to_i
        next unless item_ids.include?(item_id) # skip incompatible (Uni Bug)
        item = items[item_id]
        unless item
          item = Item.new
          item.id = item_id
          items[item_id] = item
        end
        item.origin_registry_info = info_registry[item.id.to_s]
        item.current_body_id = pet_type.body_id

        # Build and update the SWF
        swf_asset_remote_id = asset_data[:asset_id].to_i
        swf_asset = existing_swf_assets_by_remote_id[swf_asset_remote_id]
        unless swf_asset
          swf_asset = SwfAsset.new
          swf_asset.remote_id = swf_asset_remote_id
        end
        swf_asset.origin_object_data = asset_data
        swf_asset.origin_pet_type = pet_type
        swf_asset.item = item

        # Build and update the relationship
        relationship = existing_relationships_by_item_id_and_swf_asset_id[item.id][swf_asset.id] rescue nil
        unless relationship
          relationship = ParentSwfAssetRelationship.new
          relationship.parent = item
        end
        relationship.swf_asset = swf_asset
        relationships_by_item_id[item_id] ||= []
        relationships_by_item_id[item_id] << relationship
      end
    end

    # Set up the relationships to be updated on item save
    relationships_by_item_id.each do |item_id, relationships|
      items[item_id].parent_swf_asset_relationships_to_update = relationships
    end

    items.values
  end

  class << self
    MALL_HOST = 'ncmall.neopets.com'
    MALL_MAIN_PATH = '/mall/shop.phtml'
    MALL_CATEGORY_PATH = '/mall/ajax/load_page.phtml'
    MALL_CATEGORY_QUERY = 'type=browse&cat={cat}&lang=en'
    MALL_CATEGORY_TRIGGER = /load_items_pane\("browse", ([0-9]+)\);/
    MALL_JSON_ITEM_DATA_KEY = 'object_data'
    MALL_ITEM_URL_TEMPLATE = 'http://images.neopets.com/items/%s.gif'

    MALL_MAIN_URI = Addressable::URI.new :scheme => 'http',
      :host => MALL_HOST, :path => MALL_MAIN_PATH
    MALL_CATEGORY_URI = Addressable::URI.new :scheme => 'http',
      :host => MALL_HOST, :path => MALL_CATEGORY_PATH,
      :query => MALL_CATEGORY_QUERY
    MALL_CATEGORY_TEMPLATE = Addressable::Template.new MALL_CATEGORY_URI

    def spider_mall!
      # Load the mall HTML, scan it for category onclicks
      items = {}
      spider_request(MALL_MAIN_URI).scan(MALL_CATEGORY_TRIGGER) do |match|
        # Plug the category ID into the URI for that category's JSON document
        uri = MALL_CATEGORY_TEMPLATE.expand :cat => match[0]
        begin
          # Load up that JSON and send it off to be parsed
          puts "Loading #{uri}..."
          category_items = spider_mall_category(spider_request(uri))
          puts "...found #{category_items.size} items"
          items.merge!(category_items)
        rescue SpiderJSONError => e
          # If there was a parsing error, add where it came from
          Rails.logger.warn "Error parsing JSON at #{uri}, skipping: #{e.message}"
        end
      end
      puts "#{items.size} items found"
      all_item_ids = items.keys
      # Find which of these already exist but aren't marked as sold_in_mall so
      # we can update them as being sold
      Item.not_sold_in_mall.where(:id => items.keys).select([:id, :name]).each do |item|
        items.delete(item.id)
        item.sold_in_mall = true
        item.save
        puts "#{item.name} (#{item.id}) now in mall, updated"
      end
      # Find items marked as sold_in_mall so we can skip those we just found
      # if they already are properly marked, and mark those that we didn't just
      # find as no longer sold_in_mall
      Item.sold_in_mall.select([:id, :name]).each do |item|
        if all_item_ids.include?(item.id)
          items.delete(item.id)
        else
          item.sold_in_mall = false
          item.save
          puts "#{item.name} (#{item.id}) no longer in mall, removed sold_in_mall status"
        end
      end
      puts "#{items.size} new items"
      items.each do |item_id, item|
        item.save
        puts "Saved #{item.name} (#{item_id})"
      end
      items
    end

    def spider_mall_assets!(limit)
      items = self.select([arel_table[:id], arel_table[:name]]).sold_in_mall.spidered_longest_ago.limit(limit).all
      puts "- #{items.size} items need asset spidering"
      AssetStrategy.build_strategies
      items.each do |item|
        AssetStrategy.spider item
      end
    end

    def spider_request(uri)
      begin
        response = Net::HTTP.get_response uri
      rescue SocketError => e
        raise SpiderHTTPError, "Error loading #{uri}: #{e.message}"
      end
      unless response.is_a? Net::HTTPOK
        raise SpiderHTTPError, "Error loading #{uri}: Response was a #{response.class}"
      end
      response.body
    end

    private

    class AssetStrategy
      Strategies = {}

      MALL_ASSET_PATH = '/mall/ajax/get_item_assets.phtml'
      MALL_ASSET_QUERY = 'pet={pet_name}&oii={item_id}'
      MALL_ASSET_URI = Addressable::URI.new :scheme => 'http',
        :host => MALL_HOST, :path => MALL_ASSET_PATH,
        :query => MALL_ASSET_QUERY
      MALL_ASSET_TEMPLATE = Addressable::Template.new MALL_ASSET_URI

      def initialize(name, options)
        @name = name
        @pass = options[:pass]
        @complete = options[:complete]
        @pet_types = options[:pet_types]
      end

      def spider(item)
        puts "  - Using #{@name} strategy"
        exit = false
        @pet_types.each do |pet_type|
          swf_assets = load_for_pet_type(item, pet_type)
          if swf_assets
            contains_body_specific_assets = false
            swf_assets.each do |swf_asset|
              if swf_asset.body_specific?
                contains_body_specific_assets = true
                break
              end
            end
            if contains_body_specific_assets
              if @pass
                Strategies[@pass].spider(item) unless @pass == :exit
                exit = true
                break
              end
            else
              # if all are universal, no need to spider more
              puts "    - No body specific assets; moving on"
              exit = true
              break
            end
          end
        end
        if !exit && @complete && @complete != :exit
          Strategies[@complete].spider(item)
        end
      end

      private

      def load_for_pet_type(item, pet_type, banned_pet_ids=[])
        pet_id = pet_type.pet_id
        pet_name = pet_type.pet_name
        pet_valid = nil
        begin
          pet = Pet.load(pet_name)
          if pet.pet_type_id == pet_type.id
            pet_valid = true
          else
            pet_valid = false
            puts "    - Pet #{pet_name} is pet type \##{pet.pet_type_id}, not \##{pet_type.id}; saving it and loading new pet"
            pet.save!
          end
        rescue Pet::PetNotFound
          pet_valid = false
          puts "    - Pet #{pet_name} no longer exists; destroying and loading new pet"
          Pet.find_by_name(pet_name).destroy
        end
        if pet_valid
          swf_assets = load_for_pet_name(item, pet_type, pet_name)
          if swf_assets
            puts "    - Modeled with #{pet_name}, saved assets (#{swf_assets.map(&:id).join(', ')})"
          else
            puts "    - Item #{item.name} does not fit #{pet_name}"
          end
          return swf_assets
        else
          banned_pet_ids << pet_id
          new_pet = pet_type.pets.select([:id, :name]).where(Pet.arel_table[:id].not_in(banned_pet_ids)).first
          if new_pet
            pet_type.pet_id = new_pet.id
            pet_type.pet_name = new_pet.name
            load_for_pet_type(item, pet_type, banned_pet_ids)
          else
            puts "    - We have no more pets of type \##{pet_type.id}. Skipping"
            return nil
          end
        end
      end

      def load_for_pet_name(item, pet_type, pet_name)
        uri = MALL_ASSET_TEMPLATE.
          expand(
            :item_id => item.id,
            :pet_name => pet_name
          )
        raw_data = Item.spider_request(uri)
        data = JSON.parse(raw_data)
        item_id_key = item.id.to_s
        if !data.empty? && data[item_id_key] && data[item_id_key]['asset_data']
          data[item_id_key]['asset_data'].map do |asset_id_str, asset_data|
            item.zones_restrict = asset_data['restrict']
            item.save
            swf_asset = SwfAsset.find_or_initialize_by_type_and_remote_id(SwfAssetType, asset_id_str.to_i)
            swf_asset.type = SwfAssetType
            swf_asset.body_id = pet_type.body_id
            swf_asset.mall_data = asset_data
            item.swf_assets << swf_asset unless item.swf_assets.include? swf_asset
            swf_asset.save
            swf_asset
          end
        else
          nil
        end
      end

      class << self
        def add_strategy(name, options)
          Strategies[name] = new(name, options)
        end

        def add_cascading_strategy(name, options)
          pet_type_groups = options[:pet_types]
          pet_type_group_names = pet_type_groups.keys
          pet_type_group_names.each_with_index do |pet_type_group_name, i|
            remaining_pet_types = pet_type_groups[pet_type_group_name]
            first_pet_type = [remaining_pet_types.slice!(0)]
            cascade_name = "#{name}_cascade"
            next_name = pet_type_group_names[i + 1]
            next_name = next_name ? "group_#{next_name}" : options[:complete]
            first_strategy_options = {:complete => next_name, :pass => :exit,
              :pet_types => first_pet_type}
            unless remaining_pet_types.empty?
              first_strategy_options[:pass] = cascade_name
              add_strategy cascade_name, :complete => :exit,
                :pet_types => remaining_pet_types
            end
            add_strategy name, first_strategy_options
            name = next_name
          end
        end

        def spider(item)
          puts "- Spidering for #{item.name}"
          Strategies[:start].spider(item)
          item.last_spidered = Time.now
          item.save
          puts "- #{item.name} done spidering, saved last spidered timestamp"
        end

        def build_strategies
          if Strategies.empty?
            pet_type_t = PetType.arel_table
            require 'pet' # FIXME: console is whining when i don't do this
            pet_t = Pet.arel_table
            pet_types = PetType.select([pet_type_t[:id], pet_type_t[:body_id], "#{Pet.table_name}.id as pet_id, #{Pet.table_name}.name as pet_name"]).
              joins(:pets).group(pet_type_t[:id])
            remaining_standard_pet_types = pet_types.single_standard_color.order(:species_id)
            first_standard_pet_type = [remaining_standard_pet_types.slice!(0)]

            add_strategy :start, :pass => :remaining_standard, :complete => :first_nonstandard_color,
              :pet_types => first_standard_pet_type

            add_strategy :remaining_standard, :complete => :exit,
              :pet_types => remaining_standard_pet_types

            add_cascading_strategy :first_nonstandard_color, :complete => :remaining_standard,
              :pet_types => pet_types.select(pet_type_t[:color_id]).nonstandard_colors.all.group_by(&:color_id)
          end
        end
      end
    end

    def spider_mall_category(json)
      begin
        items_data = JSON.parse(json)[MALL_JSON_ITEM_DATA_KEY]
        unless items_data
          raise SpiderJSONError, "Missing key #{MALL_JSON_ITEM_DATA_KEY}"
        end
      rescue Exception => e
        # Catch both errors parsing JSON and the missing key
        raise SpiderJSONError, e.message
      end
      items = {}
      items_data.each do |item_id, item_data|
        if item_data['isWearable'] == 1
          relevant_item_data = item_data.slice('name', 'description', 'price')
          item = Item.new relevant_item_data
          item.id = item_data['id']
          item.thumbnail_url = sprintf(MALL_ITEM_URL_TEMPLATE, item_data['imageFile'])
          item.sold_in_mall = true
          items[item.id] = item
        end
      end
      items
    end

    class SpiderError < RuntimeError;end
    class SpiderHTTPError < SpiderError;end
    class SpiderJSONError < SpiderError;end
  end
end
