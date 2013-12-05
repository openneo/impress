class PetTypeObserver < ActiveRecord::Observer
  include FragmentExpiration
  
  def after_create(pet_type)
    images_key = "items/show standard_species_images special_color=#{pet_type.color_id}"
    expire_fragment_in_all_locales(images_key)
  end
end
