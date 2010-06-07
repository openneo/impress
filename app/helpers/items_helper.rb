module ItemsHelper
  StandardSpeciesImageFormat = 'http://pets.neopets.com/cp/%s/1/1.png'
  
  def standard_species_images(species_list)
    pet_types = PetType.random_basic_per_species(species_list.map(&:id))
    raw(pet_types.inject('') do |html, pet_type|
      src = sprintf(StandardSpeciesImageFormat, pet_type.image_hash)
      human_name = pet_type.species.name.humanize
      image = image_tag(src, :alt => human_name, :title => human_name)
      attributes = {
        'data-id' => pet_type.id,
        'data-body-id' => pet_type.body_id
      }
      [:color, :species].each do |pet_type_attribute_name|
        pet_type_attribute = pet_type.send(pet_type_attribute_name)
        [:id, :name].each do |subattribute_name|
          attributes["data-#{pet_type_attribute_name}-#{subattribute_name}"] =
            pet_type_attribute.send(subattribute_name)
        end
      end
      html + link_to(
        image,
        '#',
        attributes
      )
    end)
  end
end
