class PetAttribute < StaticResource
  def as_json(options={})
    {
      :id => self.id,
      :name => self.human_name
    }
  end
  
  def human_name
    self.name.capitalize
  end
  
  class << self
    def all_ordered_by_name
      @objects_ordered_by_name
    end
    
    def find(id)
      attribute = super
      unless attribute
        attribute = new
        attribute.id = id
        attribute.name = "color \##{id}"
      end
      attribute
    end
    
    def find_by_name(name)
      @objects_by_name[name.downcase]
    end
  end
  
  private
  
  def self.data_source
    "#{to_s.downcase.pluralize}.txt"
  end
  
  def self.process_line(line)
    name = line.chomp.downcase
    @objects << @objects_by_name[name] = species = new
    species.id = @objects.size
    species.name = name
  end
  
  def self.fetch_objects!
    @objects = []
    @objects_by_name = {}
    File.open(Rails.root.join('config', data_source)).each do |line|
      process_line(line)
    end
    @objects_ordered_by_name = @objects.sort { |a,b| a.name <=> b.name }
  end
end
