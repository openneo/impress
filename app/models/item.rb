require "async"
require "async/barrier"

class Item < ApplicationRecord
  include PrettyParam
  include Item::Dyeworks
  
  # We use the `type` column to mean something other than what Rails means!
  self.inheritance_column = nil

  SwfAssetType = 'object'

  serialize :cached_compatible_body_ids, coder: Serializers::IntegerSet
  serialize :cached_occupied_zone_ids, coder: Serializers::IntegerSet

  has_many :closet_hangers
  has_one :contribution, as: :contributed, inverse_of: :contributed
  has_one :nc_mall_record
  has_many :parent_swf_asset_relationships, as: :parent
  has_many :swf_assets, through: :parent_swf_asset_relationships
  belongs_to :dyeworks_base_item, class_name: "Item",
    default: -> { inferred_dyeworks_base_item }, optional: true
  has_many :dyeworks_variants, class_name: "Item",
    inverse_of: :dyeworks_base_item

  validates_presence_of :name, :description, :thumbnail_url, :rarity, :price,
    :zones_restrict

  attr_writer :current_body_id, :owned, :wanted

  NCRarities = [0, 500]
  PAINTBRUSH_SET_DESCRIPTION = 'This item is part of a deluxe paint brush set!'

  scope :newest, -> {
    order(arel_table[:created_at].desc) if arel_table[:created_at]
  }

  scope :sitemap, -> { order([:id]).limit(49999) }

  scope :name_includes, ->(value) {
    Item.where("name LIKE ?", "%" + sanitize_sql_like(value) + "%")
  }
  scope :name_excludes, ->(value) {
    Item.where("name NOT LIKE ?", "%" + sanitize_sql_like(value) + "%")
  }
  scope :is_nc, -> {
    i = Item.arel_table
    where(i[:rarity_index].in(Item::NCRarities).or(i[:is_manually_nc].eq(true)))
  }
  scope :is_not_nc, -> {
    i = Item.arel_table
    where(i[:rarity_index].in(Item::NCRarities).or(i[:is_manually_nc].eq(true)).not)
  }
  scope :is_np, -> {
    self.is_not_nc.is_not_pb
  }
  scope :is_not_np, -> {
    self.merge Item.is_nc.or(Item.is_pb)
  }
  scope :is_pb, -> {
    where('description LIKE ?',
      '%' + sanitize_sql_like(PAINTBRUSH_SET_DESCRIPTION) + '%')
  }
  scope :is_not_pb, -> {
    where('description NOT LIKE ?',
      '%' + sanitize_sql_like(PAINTBRUSH_SET_DESCRIPTION) + '%')
  }
  scope :occupies, ->(zone_label) {
    Zone.matching_label(zone_label).
      map { |z| occupies_zone_id(z.id) }.reduce(none, &:or)
  }
  scope :not_occupies, ->(zone_label) {
    Zone.matching_label(zone_label).
      map { |z| not_occupies_zone_id(z.id) }.reduce(all, &:and)
  }
  scope :occupies_zone_id, ->(zone_id) {
    where("FIND_IN_SET(?, cached_occupied_zone_ids) > 0", zone_id)
  }
  scope :not_occupies_zone_id, ->(zone_id) {
    where.not("FIND_IN_SET(?, cached_occupied_zone_ids) > 0", zone_id)
  }
  scope :restricts, ->(zone_label) {
    zone_ids = Zone.matching_label(zone_label).map(&:id)
    condition = zone_ids.map { '(SUBSTR(items.zones_restrict, ?, 1) = "1")' }.join(' OR ')
    where(condition, *zone_ids)
  }
  scope :not_restricts, ->(zone_label) {
    zone_ids = Zone.matching_label(zone_label).map(&:id)
    condition = zone_ids.map { '(SUBSTR(items.zones_restrict, ?, 1) = "1")' }.join(' OR ')
    where("NOT (#{condition})", *zone_ids)
  }
  scope :fits, ->(body_id) {
    where("FIND_IN_SET(?, cached_compatible_body_ids) > 0", body_id).
      or(where("FIND_IN_SET('0', cached_compatible_body_ids) > 0"))
  }
  scope :not_fits, ->(body_id) {
    where.not("FIND_IN_SET(?, cached_compatible_body_ids) > 0", body_id).
      and(where.not("FIND_IN_SET('0', cached_compatible_body_ids) > 0"))
  }

  def nc_trade_value
    return nil unless nc?

    # Load the trade value, if we haven't already. Note that, because the trade
    # value may be nil, we also save an explicit boolean for whether we've
    # already looked it up, rather than checking if the saved value is empty.
    return @nc_trade_value if @nc_trade_value_loaded

    @nc_trade_value = begin
      Rails.logger.debug "Item #{id} (#{name}) <lookup>"
      OwlsValueGuide.find_by_name(name)
    rescue OwlsValueGuide::NotFound => error
      Rails.logger.debug("No NC trade value listed for #{name} (#{id})")
      nil
    rescue OwlsValueGuide::NetworkError => error
      Rails.logger.error("Couldn't load nc_trade_value: #{error.full_message}")
      nil
    end

    @nc_trade_value_loaded = true
    @nc_trade_value
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
    is_manually_nc? || NCRarities.include?(rarity_index)
  end
  
  def pb?
    I18n.with_locale(:en) { self.description == PAINTBRUSH_SET_DESCRIPTION }
  end

  def np?
    !nc? && !pb?
  end

  def currently_in_mall?
    nc_mall_record.present?
  end

  def source
    if dyeworks_buyable?
      :dyeworks
    elsif currently_in_mall?
      :nc_mall
    elsif nc?
      :other_nc
    elsif np?
      :np
    elsif pb?
      :pb
    else
      raise "Item has no matching source (should not happen?)"
    end
  end

  def owned?
    @owned || false
  end

  def wanted?
    @wanted || false
  end

  def current_nc_price
    nc_mall_record&.current_price
  end

  # If this is a PB item, return the corresponding Color, inferred from the
  # item name. If it's not a PB item, or we fail to infer a specific color,
  # return nil. (This is expected to be nil for some PB items, like the "Aisha
  # Collar", which belong to many colors. It can also be nil for PB items for
  # new colors we haven't manually added to the database yet, or if a PB item
  # is named strangely in the future.)
  def pb_color
    return nil unless pb?

    # NOTE: To handle colors like "Royalboy", where the items aren't consistent
    # with the color name regarding whether or not there's spaces, we remove
    # all spaces from the item name and color name when matching. We also
    # hackily handle the fact that "Elderlyboy" color has items named "Elderly
    # Male" (and same for Girl/Female) by replacing those words, too. These
    # hacks could cause false matches in theory, but I'm not aware of any rn!
    normalized_name = name.downcase.gsub("female", "girl").gsub("male", "boy").
      gsub(/\s/, "")

    # For each color, normalize its name, look for it in the item name, and
    # return the matching color that appears earliest. (This is important for
    # items that contain multiple color names, like the "Royal Girl Elephante
    # Gold Bracelets".)
    Color.all.to_h { |c| [c, c.name.downcase.gsub(/\s/, "")] }.
      transform_values { |n| normalized_name.index(n) }.
      filter { |c, n| n.present? }.
      min_by { |c, i| i }&.first
  end

  # If this is a PB item, return the corresponding Species, inferred from the
  # item name. If it's not a PB item, or we fail to infer a specific species,
  # return nil. (This is not expected to be nil in general, but could be for PB
  # items for new species we haven't manually added to the database yet, or if
  # a PB item is named strangely in the future.)
  def pb_species
    return nil unless pb?
    normalized_name = name.downcase
    Species.order(:name).find { |s| normalized_name.include?(s.name.downcase) }
  end

  def pb_item_name
    pb_color&.pb_item_name
  end

  def restricted_zones(options={})
    options[:scope] ||= Zone.all
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

  def occupied_zones
    zone_ids = swf_assets.map(&:zone_id).uniq
    Zone.find(zone_ids)
  end

  def affected_zones
    restricted_zones + occupied_zones
  end

  def update_cached_fields
    self.cached_occupied_zone_ids = occupied_zone_ids
    self.cached_compatible_body_ids = compatible_body_ids(use_cached: false)
    self.save!
  end

  def species_support_ids
    @species_support_ids_array ||= read_attribute('species_support_ids').split(',').map(&:to_i) rescue nil
  end

  def species_support_ids=(replacement)
    @species_support_ids_array = nil
    replacement = replacement.join(',') if replacement.is_a?(Array)
    write_attribute('species_support_ids', replacement)
  end

  def predicted_body_ids
    @predicted_body_ids ||= if compatible_body_ids.include?(0)
      # Oh, look, it's already known to fit everybody! Sweet. We're done. (This
      # isn't folded into the case below, in case this item somehow got a
      # body-specific and non-body-specific asset. In all the cases I've seen
      # it, that indicates a glitched item, but this method chooses to reflect
      # behavior elsewhere in the app by saying that we can put this item on
      # anybody. (Heh. Any body.))
      compatible_body_ids
    elsif compatible_body_ids.size == 1
      # This might just be a species-specific item. Let's be conservative in
      # our prediction, though we'll revise it if we see another body ID.
      compatible_body_ids
    elsif compatible_body_ids.size == 0
      # If somehow we have this item, but not any modeling data for it (weird!),
      # consider it to fit all standard pet types until shown otherwise.
      PetType.basic.distinct.pluck(:body_id).sort
    else
      # First, find our compatible pet types, then pair each body ID with its
      # color. (As an optimization, we omit standard colors, other than the
      # basic colors. We also flatten the basic colors into the single color
      # ID "basic", so we can treat them specially.)
      compatible_pairs = compatible_pet_types.joins(:color).
        merge(Color.nonstandard.or(Color.basic)).
        distinct.pluck(
          Arel.sql("IF(colors.basic, 'basic', colors.id)"), :body_id)

      # Group colors by body, to help us find bodies unique to certain colors.
      compatible_color_ids_by_body_id = {}.tap do |h|
        compatible_pairs.each do |(color_id, body_id)|
          h[body_id] ||= []
          h[body_id] << color_id
        end
      end

      # Find non-basic colors with at least one unique compatible body. (This
      # means we'll ignore e.g. the Maraquan Mynci, which has the same body as
      # the Blue Mynci, as not indicating Maraquan compatibility in general.)
      modelable_color_ids =
        compatible_color_ids_by_body_id.
          filter { |k, v| v.size == 1 && v.first != "basic" }.
          values.map(&:first).uniq

      # We can model on basic pets (perhaps in addition to the above) if we
      # find at least one compatible basic body that doesn't *also* fit any of
      # the modelable colors we identified above.
      basic_is_modelable =
        compatible_color_ids_by_body_id.values.
          any? { |v| v.include?("basic") && (v & modelable_color_ids).empty? }

      # Get all body IDs for the colors we decided are modelable.
      predicted_pet_types =
        (basic_is_modelable ? PetType.basic : PetType.none).
          or(PetType.where(color_id: modelable_color_ids))
      predicted_pet_types.distinct.pluck(:body_id).sort
    end
  end

  def predicted_missing_body_ids
    @predicted_missing_body_ids ||= predicted_body_ids - compatible_body_ids
  end

  def predicted_missing_standard_body_ids_by_species_id
    @predicted_missing_standard_body_ids_by_species_id ||=
      PetType.select('DISTINCT body_id, species_id').
              joins(:color).
              where(body_id: predicted_missing_body_ids,
                    colors: {standard: true}).
              inject({}) { |h, pt| h[pt.species_id] = pt.body_id; h }
  end

  def predicted_missing_standard_body_ids_by_species
    species = Species.where(id: predicted_missing_standard_body_ids_by_species_id.keys)
    species_by_id = species.inject({}) { |h, s| h[s.id] = s; h }
    predicted_missing_standard_body_ids_by_species_id.inject({}) { |h, (sid, bid)|
      h[species_by_id[sid]] = bid; h }
  end

  def predicted_missing_nonstandard_body_pet_types
    body_ids = predicted_missing_body_ids - PetType.basic_body_ids
    PetType.joins(:color).where(body_id: body_ids, colors: {standard: false})
  end

  def predicted_missing_nonstandard_body_ids_by_species_by_color
    pet_types = predicted_missing_nonstandard_body_pet_types

    species_by_id = {}
    Species.find(pet_types.map(&:species_id)).each do |species|
      species_by_id[species.id] = species
    end

    colors_by_id = {}
    Color.find(pet_types.map(&:color_id)).each do |color|
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
    compatible_body_ids.size.to_f / predicted_body_ids.size
  end

  def as_json(options={})
    super({
      only: [:id, :name, :description, :thumbnail_url, :rarity_index],
      methods: [:zones_restrict],
    }.merge(options))
  end

  def compatible_body_ids(use_cached: true)
    return cached_compatible_body_ids if use_cached

    swf_assets.map(&:body_id).uniq
  end

  def compatible_pet_types
    return PetType.all if compatible_body_ids.include?(0)
    PetType.where(body_id: compatible_body_ids)
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

    # NOTE: If some of these fields are missing, it could cause saving the item
    # to fail, because many of these columns are non-nullable.
    self.name = info['name']
    self.description = info['description']
    self.thumbnail_url = info['thumbnail_url']
    self.category = info['category']
    self.type = info['type']
    self.rarity = info['rarity']
    self.rarity_index = info['rarity_index'].to_i
    self.price = info['price'].to_i
    self.weight_lbs = info['weight_lbs'].to_i
    self.zones_restrict = info['zones_restrict']
  end

  def pending_swf_assets
    @parent_swf_asset_relationships_to_update.inject([]) do |all_swf_assets, relationship|
      all_swf_assets << relationship.swf_asset
    end
  end

  def parent_swf_asset_relationships_to_update=(rels)
    @parent_swf_asset_relationships_to_update = rels
  end

  # NOTE: Adding the JSON serializer makes `as_json` treat this like a model
  # instead of like a hash, so you can target its children with things like
  # the `include` option. This feels clunky though, I wish I had something a
  # bit more suited to it!
  Appearance = Struct.new(:item, :body, :swf_assets) do
    include ActiveModel::Serializers::JSON
    delegate :present?, :empty?, to: :swf_assets
    delegate :species, :fits?, :fits_all?, to: :body

    def attributes
      {item:, body:, swf_assets:}
    end

    def html5?
      swf_assets.all?(&:html5?)
    end

    def occupied_zone_ids
      swf_assets.map(&:zone_id).uniq.sort
    end

    def restricted_zone_ids
      return [] if empty?
      ([item] + swf_assets).map(&:restricted_zone_ids).flatten.uniq.sort
    end
  end
  Appearance::Body = Struct.new(:id, :species) do
    include ActiveModel::Serializers::JSON
    def attributes
      {id:, species:}
    end

    def fits_all?
      id == 0
    end

    def fits?(target)
      fits_all? || target.body_id == id
    end
  end

  def appearances
    @appearances ||= build_appearances
  end

  def build_appearances
    all_swf_assets = swf_assets.to_a

    # If there are no assets yet, there are no appearances.
    return [] if all_swf_assets.empty?

    # Get all SWF assets, and separate the ones that fit everyone (body_id=0).
    swf_assets_by_body_id = all_swf_assets.group_by(&:body_id)
    swf_assets_for_all_bodies = swf_assets_by_body_id.delete(0) || []

    # If there are no body-specific assets, return one appearance for them all.
    if swf_assets_by_body_id.empty?
      body = Appearance::Body.new(0, nil)
      return [Appearance.new(self, body, swf_assets_for_all_bodies)]
    end

    # Otherwise, create an appearance for each real (nonzero) body ID. We don't
    # generally expect body_id = 0 and body_id != 0 to mix, but if they do,
    # uhh, let's merge the body_id = 0 ones in?
    species_by_body_id = Species.with_body_ids(swf_assets_by_body_id.keys)
    swf_assets_by_body_id.map do |body_id, body_specific_assets|
      swf_assets_for_body = body_specific_assets + swf_assets_for_all_bodies
      body = Appearance::Body.new(body_id, species_by_body_id[body_id])
      Appearance.new(self, body, swf_assets_for_body)
    end
  end

  def appearance_for(target, ...)
    Item.appearances_for([self], target, ...)[id]
  end

  def appearances_by_occupied_zone_id
    {}.tap do |h|
      appearances.each do |appearance|
        appearance.occupied_zone_ids.each do |zone_id|
          h[zone_id] ||= []
          h[zone_id] << appearance
        end
      end
    end
  end

  def appearances_by_occupied_zone
    zones_by_id = occupied_zones.to_h { |z| [z.id, z] }
    appearances_by_occupied_zone_id.transform_keys { |zid| zones_by_id[zid] }
  end

  # Given a list of items, return how they look on the given target (either a
  # pet type or an alt style).
  def self.appearances_for(items, target, swf_asset_includes: [])
    # First, load all the relationships for these items that also fit this
    # body.
    relationships = ParentSwfAssetRelationship.
      includes(swf_asset: swf_asset_includes).
      where(parent_type: "Item", parent_id: items.map(&:id)).
      where(swf_asset: {body_id: [target.body_id, 0]})

    pet_type_body = Appearance::Body.new(target.body_id, target.species)
    all_pets_body = Appearance::Body.new(0, nil)

    # Then, convert this into a hash from item ID to SWF assets.
    assets_by_item_id = relationships.group_by(&:parent_id).
      transform_values { |rels| rels.map(&:swf_asset) }

    # Finally, for each item, return an appearance—even if it's empty!
    items.to_h do |item|
      assets = assets_by_item_id.fetch(item.id, [])

      fits_all_pets = assets.present? && assets.all? { |a| a.body_id == 0 }
      body = fits_all_pets ? all_pets_body : pet_type_body

      [item.id, Appearance.new(item, body, assets)]
    end
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

  def self.preload_nc_trade_values(items)
    # Only allow 10 trade values to be loaded at a time.
    barrier = Async::Barrier.new
    semaphore = Async::Semaphore.new(10, parent: barrier)

    Sync do
      # Load all the trade values in concurrent async tasks. (The
      # `nc_trade_value` caches the value in the Item object.)
      items.each do |item|
        semaphore.async { item.nc_trade_value }
      end

      # Wait until all tasks are done.
      barrier.wait
    ensure
      barrier.stop # If something goes wrong, clean up all tasks.
    end

    items
  end

  def self.collection_from_pet_type_and_registries(pet_type, info_registry, asset_registry, scope=Item.all)
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
end
