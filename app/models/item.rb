class Item < ActiveRecord::Base
  include SwfAssetParent
  
  SwfAssetType = 'object'
  
  set_table_name 'objects' # Neo & PHP Impress call them objects, but the class name is a conflict (duh!)
  set_inheritance_column 'inheritance_type' # PHP Impress used "type" to describe category
  
  cattr_reader :per_page
  @@per_page = 30
  
  scope :alphabetize, order('name ASC')
  
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
        query_conditions.last.to_property!
      elsif c == '-' && !in_phrase && query_conditions.last.empty?
        query_conditions.last.negate!
      else
        query_conditions.last << c
      end
    end
    query_conditions.inject(self) do |scope, condition|
      condition.narrow(scope)
    end
  end
  
  private
  
  class Condition < String
    def to_property!
      @property = self.clone
      self.replace ''
    end
    
    def negate!
      @negative = true
    end
    
    def narrow(scope)
      items = Table(:objects)
      if @property == 'species' || @property == 'only'
        species = Species.find_by_name(self)
        raise ArgumentError, "Species \"#{self.humanize}\" does not exist" unless species
        # TODO: add a many-to-many table to handle this relationship, if
        # performance becomes an issue
        ids = items[:species_support_ids]
        if @property == 'species'
          condition = ids.eq('').or(ids.matches_any(
            species.id,
            "#{species.id},%",
            "%,#{species.id},%",
            "%,#{species.id}"
          ))
        else
          condition = items[:species_support_ids].eq(species.id.to_s)
        end
      elsif @property == 'description' || @property.blank?
        column = @property == 'description' ? :description : :name
        condition = items[column].matches("%#{self}%")
      else
        raise ArgumentError, "Unknown search filter \"#{@property}\""
      end
      condition = condition.not if @negative
      scope.where(condition)
    end
    
    def inspect
      @property ? "#{@property}:#{super}" : super
    end
  end
end
