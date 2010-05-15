class Item < ActiveRecord::Base
  set_table_name 'objects' # Neo & PHP Impress call them objects, but the class name is a conflict (duh!)
  set_inheritance_column 'inheritance_type' # PHP Impress used "type" to describe category
  
  # Not defining validations, since this app is currently read-only
  
  def species_support_ids
    @species_support_ids_array ||= read_attribute('species_support_ids').split(',').map(&:to_i)
  end
  
  def species_support_ids=(replacement)
    replacement = replacement.join(',') if replacement.is_a?(Array)
    write_attribute('species_support_ids', replacement)
  end
  
  def self.search(query)
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
      if @property == 'species'
        species = Species.find_by_name(self)
        # TODO: add a many-to-many table to handle this relationship
        condition = items[:species_support_ids].matches_any(
          species.id,
          "#{species.id},%",
          "%,#{species.id},%",
          "%,#{species.id}"
        )
      else
        matcher = "%#{self}%"
        condition = items[:name].matches(matcher).or(
          items[:description].matches(matcher)
        )
      end
      condition = condition.not if @negative
      scope.where(condition)
    end
    
    def inspect
      @property ? "#{@property}:#{super}" : super
    end
  end
end
