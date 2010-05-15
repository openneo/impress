class Species
  attr_accessor :id, :name
  
  @objects = []
  @objects_by_name = {}
  File.open(Rails.root.join('config', 'species.txt')).each do |line|
    name = line.chomp.downcase
    @objects << @objects_by_name[name] = species = Species.new
    species.id = @objects.size
    species.name = name
  end
  
  def self.find(id)
    @objects[id-1]
  end
  
  def self.find_by_name(name)
    @objects_by_name[name.downcase]
  end
end
