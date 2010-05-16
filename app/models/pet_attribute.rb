class PetAttribute
  attr_accessor :id, :name
  
  def self.all
    @objects
  end
  
  def self.find(id)
    @objects[id-1]
  end
  
  def self.find_by_name(name)
    @objects_by_name[name.downcase]
  end
  
  private
  
  def self.fetch_objects!
    @objects = []
    @objects_by_name = {}
    
    filename = "#{to_s.downcase.pluralize}.txt"
    
    File.open(Rails.root.join('config', filename)).each do |line|
      name = line.chomp.downcase
      @objects << @objects_by_name[name] = species = new
      species.id = @objects.size
      species.name = name
    end
  end
end
