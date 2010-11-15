module ItemsHelper
  NeoitemsURLFormat = 'http://neoitems.net/search2.php?Name=%s&AndOr=and&Category=All&Special=0&Status=Active&Sort=ItemID&results=15&SearchType=8'
  module PetTypeImage
    Format = 'http://pets.neopets.com/cp/%s/%i/%i.png'
    
    Emotions = {
      :happy => 1,
      :sad => 2,
      :angry => 3,
      :ill => 4
    }
    
    Sizes = {
      :face => 1,
      :thumb => 2,
      :zoom => 3,
      :full => 4
    }
  end
  
  def standard_species_search_links
    build_on_random_standard_pet_types(Species.all) do |pet_type|
      image = pet_type_image(pet_type, :happy, :zoom)
      query = "species:#{pet_type.species.name}"
      link_to(image, items_path(:q => query))
    end
  end
  
  def standard_species_images(species)
    build_on_random_standard_pet_types(species) do |pet_type|
      image = pet_type_image(pet_type, :happy, :face)
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
      link_to(
        image,
        '#',
        attributes
      )
    end
  end
  
  def list_zones(zones, method=:label)
    zones.sort { |x,y| x.label <=> y.label }.map(&method).join(', ')
  end
  
  def nc_icon_for(item)
    image_tag 'nc.png', :title => 'NC Mall Item', :alt => 'NC', :class => 'nc-icon' if item.nc?
  end
  
  def neoitems_url_for(item)
    sprintf(NeoitemsURLFormat, CGI::escape(item.name))
  end
  
  private
  
  def build_on_random_standard_pet_types(species, &block)
    raw(PetType.random_basic_per_species(species.map(&:id)).map(&block).join)
  end
  
  def pet_type_image(pet_type, emotion, size)
    emotion_id = PetTypeImage::Emotions[emotion]
    size_id = PetTypeImage::Sizes[size]
    src = sprintf(PetTypeImage::Format, pet_type.basic_image_hash, emotion_id, size_id)
    human_name = pet_type.species.name.humanize
    image_tag(src, :alt => human_name, :title => human_name)
  end
end
