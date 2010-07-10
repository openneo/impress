class Item < ActiveRecord::Base
  include SwfAssetParent
  
  SwfAssetType = 'object'
  
  set_table_name 'objects' # Neo & PHP Impress call them objects, but the class name is a conflict (duh!)
  set_inheritance_column 'inheritance_type' # PHP Impress used "type" to describe category
  
  cattr_reader :per_page
  @@per_page = 30
  
  scope :alphabetize, order('name ASC')
  
  scope :join_swf_assets, joins('INNER JOIN parents_swf_assets psa ON psa.swf_asset_type = "object" AND psa.parent_id = objects.id').
    joins('INNER JOIN swf_assets ON swf_assets.id = psa.swf_asset_id').
    group('objects.id')
  
  # Not defining validations, since this app is currently read-only
  
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
    raise ArgumentError, "Please provide a search query" unless query
    query = query.strip
    raise ArgumentError, "Search queries should be at least 3 characters" if query.length < 3
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
      :zones_restrict => zones_restrict
    }
  end
  
  private
  
  SearchFilterScopes = []
  
  def self.search_filter(name, args={})
    SearchFilterScopes << name.to_s
    scope "search_filter_#{name}", lambda { |str, negative|
      condition = yield(str)
      condition = condition.not if negative
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
  
  search_filter :is do |is_what|
    raise ArgumentError, "We don't know how an item can be \"#{is_what}\". Did you mean is:nc?" unless is_what == 'nc'
    arel_table[:rarity_index].in([0, 500])
  end
  
  search_filter :only do |species_name|
    id = Species.require_by_name(species_name).id
    arel_table[:species_support_ids].eq(id.to_s)
  end
  
  search_filter :species do |species_name|
    id = Species.require_by_name(species_name).id
    ids = arel_table[:species_support_ids]
    ids.eq('').or(ids.matches_any(
      id,
      "#{id},%",
      "%,#{id},%",
      "%,#{id}"
    ))
  end
  
  search_filter :type, {:scope => join_swf_assets} do |zone_set_name|
    zone_set = Zone::ItemZoneSets[zone_set_name]
    raise ArgumentError, "Type \"#{zone_set_name}\" does not exist" unless zone_set
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
        raise ArgumentError, "Filter #{filter} does not exist"
      end
    end
    
    def filter
      @filter || 'name'
    end
    
    def inspect
      @filter ? "#{@filter}:#{super}" : super
    end
  end
end
