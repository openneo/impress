class PetAttribute < StaticResource
  def as_json(options={})
    {
      :id => self.id,
      :name => self.name.capitalize
    }
  end
  
  def self.find_by_name(name)
    @objects_by_name[name.downcase]
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
  end
end
