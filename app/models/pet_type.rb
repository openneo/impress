class PetType < ActiveRecord::Base
  include SwfAssetParent
  
  SwfAssetType = 'biology'
  
  BasicHashes = YAML::load_file(Rails.root.join('config', 'basic_type_hashes.yml'))
  
  def as_json(options={})
    {:id => id, :body_id => body_id}
  end
  
  def color_id=(new_color_id)
    @color = nil
    write_attribute('color_id', new_color_id)
  end
  
  def color=(new_color)
    @color = new_color
    write_attribute('color_id', @color.id)
  end
  
  def color
    @color ||= Color.find(color_id)
  end
  
  def species_id=(new_species_id)
    @species = nil
    write_attribute('species_id', new_species_id)
  end
  
  def species=(new_species)
    @species = new_species
    write_attribute('species_id', @species.id)
  end
  
  def species
    @species ||= Species.find(species_id)
  end
  
  def image_hash
    BasicHashes[species.name][color.name]
  end
end
