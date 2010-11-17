class Item < ActiveRecord::Base
  SwfAssetType = 'object'
  
  has_one :contribution, :as => :contributed
  has_many :parent_swf_asset_relationships, :foreign_key => 'parent_id',
    :conditions => {:swf_asset_type => SwfAssetType}
  has_many :swf_assets, :through => :parent_swf_asset_relationships, :source => :object_asset
  
  attr_writer :current_body_id
  
  NCRarities = [0, 500]
  PaintbrushSetDescription = 'This item is part of a deluxe paint brush set!'
  
  set_table_name 'objects' # Neo & PHP Impress call them objects, but the class name is a conflict (duh!)
  set_inheritance_column 'inheritance_type' # PHP Impress used "type" to describe category
  
  cattr_reader :per_page
  @@per_page = 30
  
  scope :alphabetize, order('name ASC')
  
  scope :join_swf_assets, joins('INNER JOIN parents_swf_assets psa ON psa.swf_asset_type = "object" AND psa.parent_id = objects.id').
    joins('INNER JOIN swf_assets ON swf_assets.id = psa.swf_asset_id').
    group('objects.id')
  
  # Not defining validations, since this app is currently read-only
  
  def nc?
    NCRarities.include?(rarity_index)
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
  
  def species_support_ids
    @species_support_ids_array ||= read_attribute('species_support_ids').split(',').map(&:to_i)
  end
  
  def species_support_ids=(replacement)
    @species_support_ids_array = nil
    replacement = replacement.join(',') if replacement.is_a?(Array)
    write_attribute('species_support_ids', replacement)
  end
  
  def supported_species
    @supported_species ||= species_support_ids.empty? ? Species.all : species_support_ids.sort.map { |id| Species.find(id) }
  end
  
  def self.search(query)
    raise SearchError, "Please provide a search query" unless query
    query = query.strip
    raise SearchError, "Search queries should be at least 3 characters" if query.length < 3
    query_conditions = [Condition.new]
    in_phrase = false
    query.each_char do |c|
      if c == ' ' && !in_phrase
        query_conditions << Condition.new
      elsif c == '"'
        in_phrase = !in_phrase
      elsif c == ':' && !in_phrase
        query_conditions.last.to_filter!
      elsif c == '-' && !in_phrase && query_conditions.last.empty?
        query_conditions.last.negate!
      else
        query_conditions.last << c
      end
    end
    query_conditions.inject(self.scoped) do |scope, condition|
      condition.narrow(scope)
    end
  end
  
  def as_json(options = {})
    {
      :description => description,
      :id => id,
      :name => name,
      :thumbnail_url => thumbnail_url,
      :zones_restrict => zones_restrict,
      :rarity_index => rarity_index
    }
  end
  
  before_create do
    self.sold_in_mall = false
    true
  end
  
  def handle_assets!
    if @parent_swf_asset_relationships_to_update && @current_body_id
      new_swf_asset_ids = @parent_swf_asset_relationships_to_update.map(&:swf_asset_id)
      rels = ParentSwfAssetRelationship.arel_table
      swf_assets = SwfAsset.arel_table
      ids_to_delete = self.parent_swf_asset_relationships.
        select(:id).
        joins(:object_asset).
        where(rels[:swf_asset_id].not_in(new_swf_asset_ids)).
        where(swf_assets[:body_id].in([@current_body_id, 0])).
        map(&:id)
      unless ids_to_delete.empty?
        ParentSwfAssetRelationship.
          where(rels[:parent_id].eq(self.id)).
          where(rels[:swf_asset_type].eq(SwfAssetType)).
          where(rels[:swf_asset_id].in(ids_to_delete)).
          delete_all
      end
      self.parent_swf_asset_relationships += @parent_swf_asset_relationships_to_update
    end
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
  
  def self.all_by_ids_or_children(ids, swf_assets)
    swf_asset_ids = []
    swf_assets_by_id = {}
    swf_assets_by_parent_id = {}
    swf_assets.each do |swf_asset|
      id = swf_asset.id
      swf_assets_by_id[id] = swf_asset
      swf_asset_ids << id
    end
    SwfAsset.select('id, parent_id').object_assets.joins(:object_asset_relationships).
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
  
  def self.collection_from_pet_type_and_registries(pet_type, info_registry, asset_registry)
    # bear in mind that registries are arrays with many nil elements,
    # due to how the parser works
    items = {}
    item_ids = []
    info_registry.each do |info|
      if info && info[:is_compatible]
        item_ids << info[:obj_info_id].to_i
      end
    end
    existing_relationships_by_item_id_and_swf_asset_id = {}
    existing_items = Item.find_all_by_id(item_ids, :include => :parent_swf_asset_relationships)
    existing_items.each do |item|
      items[item.id] = item
      relationships_by_swf_asset_id = {}
      item.parent_swf_asset_relationships.each do |relationship|
        relationships_by_swf_asset_id[relationship.swf_asset_id] = relationship
      end
      existing_relationships_by_item_id_and_swf_asset_id[item.id] =
        relationships_by_swf_asset_id
    end
    swf_asset_ids = []
    asset_registry.each_with_index do |asset_data, index|
      swf_asset_ids << index if asset_data
    end
    existing_swf_assets = SwfAsset.find_all_by_id swf_asset_ids,
      :conditions => {:type => SwfAssetType}
    existing_swf_assets_by_id = {}
    existing_swf_assets.each do |swf_asset|
      existing_swf_assets_by_id[swf_asset.id] = swf_asset
    end
    relationships_by_item_id = {}
    asset_registry.each do |asset_data|
      if asset_data
        item_id = asset_data[:obj_info_id].to_i
        next unless item_ids.include?(item_id) # skip incompatible
        item = items[item_id]
        unless item
          item = Item.new
          item.id = item_id
          items[item_id] = item
        end
        item.origin_registry_info = info_registry[item.id]
        item.current_body_id = pet_type.body_id
        swf_asset_id = asset_data[:asset_id].to_i
        swf_asset = existing_swf_assets_by_id[swf_asset_id]
        unless swf_asset
          swf_asset = SwfAsset.new
          swf_asset.id = swf_asset_id
        end
        swf_asset.origin_object_data = asset_data
        swf_asset.origin_pet_type = pet_type
        relationship = existing_relationships_by_item_id_and_swf_asset_id[item.id][swf_asset_id] rescue nil
        unless relationship
          relationship = ParentSwfAssetRelationship.new
          relationship.parent_id = item.id
          relationship.swf_asset_type = SwfAssetType
          relationship.swf_asset_id = swf_asset.id
        end
        relationship.object_asset = swf_asset
        relationships_by_item_id[item_id] ||= []
        relationships_by_item_id[item_id] << relationship
      end
    end
    relationships_by_item_id.each do |item_id, relationships|
      items[item_id].parent_swf_asset_relationships_to_update = relationships
    end
    items.values
  end
  
  private
  
  SearchFilterScopes = []
  
  def self.search_filter(name, args={})
    SearchFilterScopes << name.to_s
    scope "search_filter_#{name}", lambda { |str, negative|
      condition = yield(str)
      condition = not(condition) if negative
      rel = where(condition)
      rel = rel & args[:scope] if args[:scope]
      rel
    }
  end
  
  search_filter :name do |name|
    arel_table[:name].matches("%#{name}%")
  end
  
  search_filter :description do |description|
    arel_table[:description].matches("%#{description}%")
  end
  
  ADJECTIVE_FILTERS = {
    'nc' => arel_table[:rarity_index].in(NCRarities),
    'pb' => arel_table[:description].eq(PaintbrushSetDescription)
  }
  search_filter :is do |adjective|
    filter = ADJECTIVE_FILTERS[adjective]
    unless filter
      raise SearchError,
        "We don't know how an item can be \"#{adjective}\". " +
        "Did you mean is:nc or is:pb?"
    end
    filter
  end
  
  search_filter :only do |species_name|
    id = Species.require_by_name(species_name).id
    arel_table[:species_support_ids].eq(id.to_s)
  end
  
  search_filter :species do |species_name|
    id = Species.require_by_name(species_name).id
    ids = arel_table[:species_support_ids]
    ids.eq('').or(ids.matches_any([
      id,
      "#{id},%",
      "%,#{id},%",
      "%,#{id}"
    ]))
  end
  
  search_filter :type, {:scope => join_swf_assets} do |zone_set_name|
    zone_set = Zone::ItemZoneSets[zone_set_name]
    raise SearchError, "Type \"#{zone_set_name}\" does not exist" unless zone_set
    SwfAsset.arel_table[:zone_id].in(zone_set.map(&:id))
  end
  
  class Condition < String
    def to_filter!
      @filter = self.clone
      self.replace ''
    end
    
    def negate!
      @negative = true
    end
    
    def narrow(scope)
      if SearchFilterScopes.include?(filter)
        scope & Item.send("search_filter_#{filter}", self, @negative)
      else
        raise SearchError, "Filter #{filter} does not exist"
      end
    end
    
    def filter
      @filter || 'name'
    end
    
    def inspect
      @filter ? "#{@filter}:#{super}" : super
    end
  end
  
  class SearchError < ArgumentError;end
end
