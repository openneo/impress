class Species < PetAttribute
  fetch_objects!
  
  StandardColors = %w(blue green yellow red)
  StandardHashes = YAML::load_file(Rails.root.join('config', 'standard_type_hashes.yml'))
  
  def hash_for_color(color)
    StandardHashes[name][color]
  end
end
