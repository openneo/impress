class Item < ApplicationRecord
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
      order(it[:name].asc)
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
      where(it[:name].matches('%' + sanitize_sql_like(value) + '%'))
  }
  scope :name_excludes, ->(value, locale = I18n.locale) {
    it = Item::Translation.arel_table
    Item.joins(:translations).where(it[:locale].eq(locale)).
      where(it[:name].matches('%' + sanitize_sql_like(value) + '%').not)
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
        '%' + sanitize_sql_like(PAINTBRUSH_SET_DESCRIPTION) + '%')
  }
  scope :is_not_pb, -> {
    it = Item::Translation.arel_table
    joins(:translations).where(it[:locale].eq('en')).
      where('description NOT LIKE ?',
        '%' + sanitize_sql_like(PAINTBRUSH_SET_DESCRIPTION) + '%')
  }
  scope :occupies, ->(zone_label, locale = I18n.locale) {
    zone_ids = Zone.matching_label(zone_label, locale).map(&:id)
    sa = SwfAsset.arel_table
    joins(:swf_assets).where(sa[:zone_id].in(zone_ids)).distinct
  }
  scope :not_occupies, ->(zone_label, locale = I18n.locale) {
    zone_ids = Zone.matching_label(zone_label, locale).map(&:id)
    i = Item.arel_table
    sa = SwfAsset.arel_table
    # Querying for "has NO swf_assets matching these zone IDs" is trickier than
    # the positive case! To do it, we GROUP_CONCAT the zone_ids together for
    # each item, then use FIND_IN_SET to search the result for each zone ID,
    # and assert that it must not find a match. (This is uhh, not exactly fast,
    # so it helps to have other tighter conditions applied first!)
    # TODO: I feel like this could also be solved with a LEFT JOIN, idk if that
    # performs any better? In Rails 5+ `left_outer_joins` is built in so!
    condition = zone_ids.map { 'FIND_IN_SET(?, GROUP_CONCAT(zone_id)) = 0' }.join(' AND ')
    joins(:swf_assets).group(i[:id]).having(condition, *zone_ids).distinct
  }
  scope :restricts, ->(zone_label, locale = I18n.locale) {
    zone_ids = Zone.matching_label(zone_label, locale).map(&:id)
    condition = zone_ids.map { '(SUBSTR(items.zones_restrict, ?, 1) = "1")' }.join(' OR ')
    where(condition, *zone_ids)
  }
  scope :not_restricts, ->(zone_label, locale = I18n.locale) {
    zone_ids = Zone.matching_label(zone_label, locale).map(&:id)
    condition = zone_ids.map { '(SUBSTR(items.zones_restrict, ?, 1) = "1")' }.join(' OR ')
    where("NOT (#{condition})", *zone_ids)
  }
  scope :fits, ->(body_id) {
    sa = SwfAsset.arel_table
    joins(:swf_assets).where(sa[:body_id].eq(body_id)).distinct
  }
  scope :not_fits, ->(body_id) {
    i = Item.arel_table
    sa = SwfAsset.arel_table
    # Querying for "has NO swf_assets matching these body IDs" is trickier than
    # the positive case! To do it, we GROUP_CONCAT the body_ids together for
    # each item, then use FIND_IN_SET to search the result for the body ID,
    # and assert that it must not find a match. (This is uhh, not exactly fast,
    # so it helps to have other tighter conditions applied first!)
    #
    # TODO: I feel like this could also be solved with a LEFT JOIN, idk if that
    # performs any better? In Rails 5+ `left_outer_joins` is built in so!
    #
    # NOTE: The `fits` and `not_fits` counts don't perfectly add up to the
    # total number of items, 5 items aren't accounted for? I'm not going to
    # bother looking into this, but one thing I notice is items with no assets
    # somehow would not match either scope in this impl (but LEFT JOIN would!)
    joins(:swf_assets).group(i[:id]).
      having('FIND_IN_SET(?, GROUP_CONCAT(body_id)) = 0', body_id).
      distinct
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
    existing_items = scope.where(id: item_ids).
      includes(:parent_swf_asset_relationships)
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
      where(remote_id: swf_asset_ids)
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
end
