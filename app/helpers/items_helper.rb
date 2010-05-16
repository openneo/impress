module ItemsHelper
  StandardSpeciesImageFormat = 'http://pets.neopets.com/cp/%s/1/1.png'
  
  def standard_species_images(species_list)
    colors = Color::Basic
    pet_type = PetType.new
    raw(species_list.inject('') do |html, species|
      color = colors[rand(colors.size)]
      pet_type.species = species
      pet_type.color = color
      src = sprintf(StandardSpeciesImageFormat, pet_type.image_hash)
      human_name = species.name.humanize
      image = image_tag(src, :alt => human_name, :title => human_name)
      html + link_to(image, '#', 'data-color-id' => color.id, 'data-species-id' => species.id, 'data-species-name' => species.name)
    end)
  end
end
