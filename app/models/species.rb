class Species < PetAttribute
  fetch_objects!
  
  def self.require_by_name(name)
    species = Species.find_by_name(name)
    raise ArgumentError, "Species \"#{name.humanize}\" does not exist" unless species
    species
  end
end
