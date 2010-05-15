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
    attr_reader :property
    
    def to_property!
      @property = self.clone
      self.replace ''
    end
    
    def narrow(scope)
      if @property == 'species'
        species = Species.find_by_name(self)
        # TODO: add a many-to-many table to handle this relationship
        scope.where('species_support_ids = ? OR species_support_ids LIKE ? OR species_support_ids LIKE ? OR species_support_ids LIKE ?',
          species.id,
          "#{species.id},%",
          "%,#{species.id},%",
          "%,#{species.id}"
        )
      else
        scope.where('name LIKE :matcher OR description LIKE :matcher', :matcher => "%#{self}%")
      end
    end
    
    def inspect
      @property ? "#{@property}:#{super}" : super
    end
  end
end
