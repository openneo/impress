class Item < ActiveRecord::Base
  include PrettyParam
  
  # We use the `type` column to mean something other than what Rails means!
  self.inheritance_column = nil

  SwfAssetType = 'object'
  
  translates :name, :description, :rarity

  has_many :closet_hangers
  has_one :contribution, :as => :contributed, :inverse_of => :contributed
  has_many :parent_swf_asset_relationships, :as => :parent
  has_many :swf_assets, :through => :parent_swf_asset_relationships

  attr_writer :current_body_id, :owned, :wanted

  NCRarities = [0, 500]
  PAINTBRUSH_SET_DESCRIPTION = 'This item is part of a deluxe paint brush set!'
  SPECIAL_COLOR_DESCRIPTION_REGEX =
    /This item is only wearable by Neopets painted ([a-zA-Z]+)\.|WARNING: This [a-zA-Z]+ can be worn by ([a-zA-Z]+) [a-zA-Z]+ ONLY!|If your Neopet is not painted ([a-zA-Z]+), it will not be able to wear this item\./

  cattr_reader :per_page
  @@per_page = 30

  scope :alphabetize_by_translations, ->(locale) {
    locale = locale or I18n.locale
    it = Item::Translation.arel_table
    joins(:translations).where(it[:locale].eq('en')).
      order(it[:name])
  }

  scope :newest, -> {
    order(arel_table[:created_at].desc) if arel_table[:created_at]
  }

  scope :spidered_longest_ago, -> {
    order(["(last_spidered IS NULL) DESC", "last_spidered DESC"])
  }

  scope :sold_in_mall, -> { where(:sold_in_mall => true) }
  scope :not_sold_in_mall, -> { where(:sold_in_mall => false) }

  scope :sitemap, -> { order([:id]).limit(49999) }

  scope :with_closet_hangers, -> { joins(:closet_hangers) }

  scope :name_includes, ->(value, locale = I18n.locale) {
    it = Item::Translation.arel_table
    Item.joins(:translations).where(it[:locale].eq(locale)).
      where(it[:name].matches('%' + Item.sanitize_sql_like(value) + '%'))
  }
  scope :name_excludes, ->(value, locale = I18n.locale) {
    it = Item::Translation.arel_table
    Item.joins(:translations).where(it[:locale].eq(locale)).
      where(it[:name].matches('%' + Item.sanitize_sql_like(value) + '%').not)
  }
  scope :is_nc, -> {
    i = Item.arel_table
    where(i[:rarity_index].in(Item::NCRarities).or(i[:is_manually_nc]))
  }
  scope :is_np, -> {
    i = Item.arel_table
    where(i[:rarity_index].in(Item::NCRarities).or(i[:is_manually_nc]).not)
  }
  scope :is_pb, -> {
    it = Item::Translation.arel_table
    joins(:translations).where(it[:locale].eq('en')).
      where('description LIKE ?',
        '%' + Item.sanitize_sql_like(PAINTBRUSH_SET_DESCRIPTION) + '%')
  }
  scope :is_not_pb, -> {
    it = Item::Translation.arel_table
    joins(:translations).where(it[:locale].eq('en')).
      where('description NOT LIKE ?',
        '%' + Item.sanitize_sql_like(PAINTBRUSH_SET_DESCRIPTION) + '%')
  }
  scope :occupies, ->(zone_label, locale = I18n.locale) {
    zone_ids = Zone.matching_label(zone_label, locale).map(&:id)
    i = Item.arel_table
    sa = SwfAsset.arel_table
    joins(:swf_assets).where(sa[:zone_id].in(zone_ids)).distinct
  }
  scope :not_occupies, ->(zone_label, locale = I18n.locale) {
    # TODO: The perf on this is miserable on its own, the query plan chooses
    # a bad index for the join on parents_swf_assets here (but not in the
    # `occupies` scope?) and I don't know why! But it makes a better plan when
    # combined with `name_includes` so this is probably fine in practice?
    zone_ids = Zone.matching_label(zone_label, locale).map(&:id)
    i = Item.arel_table
    sa = SwfAsset.arel_table
    joins(:swf_assets).where(sa[:zone_id].not_in(zone_ids)).distinct
  }
  scope :restricts, ->(zone_label, locale = I18n.locale) {
    zone_ids = Zone.matching_label(zone_label, locale).map(&:id)
    condition = zone_ids.map { '(SUBSTR(zones_restrict, ?, 1) = "1")' }.join(' OR ')
    where(condition, *zone_ids)
  }
  scope :not_restricts, ->(zone_label, locale = I18n.locale) {
    zone_ids = Zone.matching_label(zone_label, locale).map(&:id)
    condition = zone_ids.map { '(SUBSTR(zones_restrict, ?, 1) = "1")' }.join(' OR ')
    where("NOT (#{condition})", *zone_ids)
  }

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
    I18n.with_locale(:en) { self.description == PAINTBRUSH_SET_DESCRIPTION }
  end

  def owned?
    @owned
  end

  def wanted?
    @wanted
  end

  def restricted_zones(options={})
    options[:scope] ||= Zone.scoped
    options[:scope].find(restricted_zone_ids)
  end
  
  def restricted_zone_ids
    unless @restricted_zone_ids
      @restricted_zone_ids = []
      zones_restrict.split(//).each_with_index do |switch, id|
        @restricted_zone_ids << (id.to_i + 1) if switch == '1'
      end
    end
    @restricted_zone_ids
  end
  
  def occupied_zone_ids
    occupied_zones.map(&:id)
  end

  def occupied_zones(options={})
    options[:scope] ||= Zone.scoped
    all_body_ids = []
    zone_body_ids = {}
    selected_assets = swf_assets.select('body_id, zone_id').each do |swf_asset|
      zone_body_ids[swf_asset.zone_id] ||= []
      body_ids = zone_body_ids[swf_asset.zone_id]
      body_ids << swf_asset.body_id unless body_ids.include?(swf_asset.body_id)
      all_body_ids << swf_asset.body_id unless all_body_ids.include?(swf_asset.body_id)
    end
    zones = options[:scope].find(zone_body_ids.keys)
    zones_by_id = zones.inject({}) { |h, z| h[z.id] = z; h }
    total_body_ids = all_body_ids.size
    zone_body_ids.each do |zone_id, body_ids|
      zones_by_id[zone_id].sometimes = true if body_ids.size < total_body_ids
    end
    zones
  end

  def affected_zones
    restricted_zones + occupied_zones
  end

  def special_color
    @special_color ||= determine_special_color
  end

  def special_color_id
    special_color.try(:id)
  end

  protected
  def determine_special_color
    I18n.with_locale(I18n.default_locale) do
      # Rather than go find the special description in all locales, let's just
      # run this logic in English.
      if description.include?(PAINTBRUSH_SET_DESCRIPTION)
        name_words = name.downcase.split
        Color.nonstandard.each do |color|
          return color if name_words.include?(color.name)
        end
      end

      match = description.match(SPECIAL_COLOR_DESCRIPTION_REGEX)
      if match
        # Since there are multiple formats in the one regex, there are multiple
        # possible color name captures. So, take the first non-nil capture.
        color = match.captures.detect(&:present?)
        return Color.find_by_name(color.downcase)
      end

      # HACK: this should probably be a flag on the record instead of
      #     being hardcoded :P
      if [71893, 76192, 76202, 77367, 77368, 77369, 77370].include?(id)
        return Color.find_by_name('baby')
      end

      if [76198].include?(id)
        return Color.find_by_name('mutant')
      end

      if [75372].include?(id)
        return Color.find_by_name('maraquan')
      end

      if manual_special_color_id?
        return Color.find(manual_special_color_id)
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
  
  def supported_species_ids
    return Species.select([:id]).map(&:id) if modeled_body_ids.include?(0)
    
    pet_types = PetType.where(:body_id => modeled_body_ids).select('DISTINCT species_id')
    species_ids = pet_types.map(&:species_id)
    
    # If there are multiple known supported species, it probably supports them
    # all. (I've never heard of only a handful of species being supported :P)
    species_ids.size >= 2 ? Species.select([:id]).map(&:id) : species_ids
  end
  
  def support_species?(species)
    species_support_ids.blank? || species_support_ids.include?(species.id)
  end

  def modeled_body_ids
    @modeled_body_ids ||= swf_assets.select('DISTINCT body_id').map(&:body_id)
  end

  def modeled_color_ids
    # Might be empty if modeled_body_ids is 0. But it's currently not called
    # in that scenario, so, whatever.
    @modeled_color_ids ||= PetType.select('DISTINCT color_id').
                                   where(body_id: modeled_body_ids).
                                   map(&:color_id)
  end

  def basic_body_ids
    @basic_body_ids ||= begin
      basic_color_ids ||= Color.select([:id]).basic.map(&:id)
      PetType.select('DISTINCT body_id').
        where(color_id: basic_color_ids).map(&:body_id)
    end
  end

  def predicted_body_ids
    @predicted_body_ids ||= if modeled_body_ids.include?(0)
      # Oh, look, it's already known to fit everybody! Sweet. We're done. (This
      # isn't folded into the case below, in case this item somehow got a
      # body-specific and non-body-specific asset. In all the cases I've seen
      # it, that indicates a glitched item, but this method chooses to reflect
      # behavior elsewhere in the app by saying that we can put this item on
      # anybody. (Heh. Any body.))
      modeled_body_ids
    elsif modeled_body_ids.size == 1
      # This might just be a species-specific item. Let's be conservative in
      # our prediction, though we'll revise it if we see another body ID.
      modeled_body_ids
    else
      # If an item is worn by more than one body, then it must be wearable by
      # all bodies of the same color. (To my knowledge, anyway. I'm not aware
      # of any exceptions.) So, let's find those bodies by first finding those
      # colors.
      basic_modeled_body_ids, nonbasic_modeled_body_ids = modeled_body_ids.
        partition { |bi| basic_body_ids.include?(bi) }

      output = []
      if basic_modeled_body_ids.present?
        output += basic_body_ids
      end
      if nonbasic_modeled_body_ids.present?
        nonbasic_modeled_color_ids = PetType.select('DISTINCT color_id').
          where(body_id: nonbasic_modeled_body_ids).
          map(&:color_id)
        output += PetType.select('DISTINCT body_id').
          where(color_id: nonbasic_modeled_color_ids).
          map(&:body_id)
      end
      output
    end
  end

  def predicted_missing_body_ids
    @predicted_missing_body_ids ||= predicted_body_ids - modeled_body_ids
  end

  def predicted_missing_standard_body_ids_by_species_id
    @predicted_missing_standard_body_ids_by_species_id ||=
      PetType.select('DISTINCT body_id, species_id').
              joins(:color).
              where(body_id: predicted_missing_body_ids,
                    colors: {standard: true}).
              inject({}) { |h, pt| h[pt.species_id] = pt.body_id; h }
  end

  def predicted_missing_standard_body_ids_by_species(species_scope=Species.scoped)
    species = species_scope.where(id: predicted_missing_standard_body_ids_by_species_id.keys)
    species_by_id = species.inject({}) { |h, s| h[s.id] = s; h }
    predicted_missing_standard_body_ids_by_species_id.inject({}) { |h, (sid, bid)|
      h[species_by_id[sid]] = bid; h }
  end

  def predicted_missing_nonstandard_body_pet_types
    PetType.joins(:color).
            where(body_id: predicted_missing_body_ids - basic_body_ids,
                  colors: {standard: false})
  end

  def predicted_missing_nonstandard_body_ids_by_species_by_color(colors_scope=Color.scoped, species_scope=Species.scoped)
    pet_types = predicted_missing_nonstandard_body_pet_types

    species_by_id = {}
    species_scope.find(pet_types.map(&:species_id)).each do |species|
      species_by_id[species.id] = species
    end

    colors_by_id = {}
    colors_scope.find(pet_types.map(&:color_id)).each do |color|
      colors_by_id[color.id] = color
    end

    body_ids_by_species_by_color = {}
    pet_types.each do |pt|
      color = colors_by_id[pt.color_id]
      body_ids_by_species_by_color[color] ||= {}
      body_ids_by_species_by_color[color][species_by_id[pt.species_id]] = pt.body_id
    end
    body_ids_by_species_by_color
  end

  def predicted_fully_modeled?
    predicted_missing_body_ids.empty?
  end

  def predicted_modeled_ratio
    modeled_body_ids.size.to_f / predicted_body_ids.size
  end

  def thumbnail
    if thumbnail_url.present?
      url = thumbnail_url
    else
      url = ActionController::Base.helpers.asset_path(
        "broken_item_thumbnail.gif")
    end
    @thumbnail ||= Image.from_insecure_url(url)
  end

  def as_json(options={})
    json = {
      :description => description,
      :id => id,
      :name => name,
      :thumbnail_url => thumbnail.secure_url,
      :zones_restrict => zones_restrict,
      :rarity_index => rarity_index,
      :nc => nc?
    }
    
    # Set owned and wanted keys, unless explicitly told not to. (For example,
    # item proxies don't want us to bother, since they'll override.)
    unless options.has_key?(:include_hanger_status)
      options[:include_hanger_status] = true
    end
    if options[:include_hanger_status]
      json[:owned] = owned?
      json[:wanted] = wanted?
    end
    
    json
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
    explicitly_body_specific? || !species_support_ids.empty?
  end

  def add_origin_registry_info(info, locale)
    # bear in mind that numbers from registries are floats
    species_support_strs = info['species_support'] || []
    self.species_support_ids = species_support_strs.map(&:to_i)

    self.name_translations = {locale => info['name']}

    attribute_names.each do |attribute|
      next if attribute == 'name'
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

  def method_cached?(method_name)
    # No methods are cached on a full item. This is for duck typing with item
    # proxies.
    false
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
    SwfAsset.object_assets.joins(:parent_swf_asset_relationships).
      where(SwfAsset.arel_table[:id].in(swf_asset_ids)).select([
        SwfAsset.arel_table[:id],
        ParentSwfAssetRelationship.arel_table[:parent_id]
      ]).each do |row|
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
    existing_swf_assets = SwfAsset.object_assets.includes(:zone).
      find_all_by_remote_id swf_asset_ids
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
        item.add_origin_registry_info info_registry[item.id.to_s], I18n.default_locale
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

  def self.build_proxies(ids)
    Item::ProxyArray.new(ids)
  end

  # TODO: Copied from modern Rails source, can delete once we're there!
  def self.sanitize_sql_like(string, escape_character = "\\")
    pattern = Regexp.union(escape_character, "%", "_")
    string.gsub(pattern) { |x| [escape_character, x].join }
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
      Item.transaction do
        # Find which of these already exist but aren't marked as sold_in_mall so
        # we can update them as being sold
        items_added_to_mall = Item.not_sold_in_mall.includes(:translations).
          where(:id => items.keys)
        items_added_to_mall.each do |item|
          items.delete(item.id)
          item.sold_in_mall = true
          item.save
          puts "#{item.name} (#{item.id}) now in mall, updated"
        end
        # Find items marked as sold_in_mall so we can skip those we just found
        # if they already are properly marked, and mark those that we didn't just
        # find as no longer sold_in_mall
        items_removed_from_mall = Item.sold_in_mall.includes(:translations)
        items_removed_from_mall.each do |item|
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
      end
      items
    end

    def spider_mall_assets!(limit)
      items = self.select([:id, :zones_restrict]).sold_in_mall.spidered_longest_ago.limit(limit).all
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

      def load_for_pet_type(item, pet_type)
        original_pet = Pet.select([:id, :name]).
          where(pet_type_id: pet_type.id).first
        if original_pet.nil?
          puts "    - We have no more pets of type \##{pet_type.id}; skipping."
          return nil
        end
        pet_id = original_pet.id
        pet_name = original_pet.name
        pet_valid = nil
        begin
          pet = Pet.load(pet_name, timeout: 10)
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
          original_pet.destroy
        rescue Pet::DownloadError => e
          puts "    - Pet #{pet_name} timed out: #{e.message}; skipping."
          return nil
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
          load_for_pet_type(item, pet_type)  # try again
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
          if item.swf_assets.present?
            puts "- #{item.name} done spidering, saved last spidered timestamp"
            item.rarity_index = 500 # a decent assumption for mall items
            item.last_spidered = Time.now
            item.save!
          else
            puts "- #{item.name} found no models, so not saved"
          end
        end

        def build_strategies
          if Strategies.empty?
            pet_type_t = PetType.arel_table
            require 'pet' # FIXME: console is whining when i don't do this
            pet_types = PetType.select([:id, :body_id])
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
