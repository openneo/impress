require 'yaml'

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
  
  StandardColors = %w(blue green yellow red)
  StandardHashes = YAML::load_file(Rails.root.join('config', 'standard_type_hashes.yml'))
  
  def hash_for_color(color)
    StandardHashes[name][color]
  end
  
  def self.all
    @objects
  end
  
  def self.find(id)
    @objects[id-1]
  end
  
  def self.find_by_name(name)
    @objects_by_name[name.downcase]
  end
end
