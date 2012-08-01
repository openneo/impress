module ContributionHelper
  def contributed_description(contributed, image = true)
    case contributed
    when Item
      contributed_item(contributed, image, 'for the first time')
    when SwfAsset
      contributed_item(contributed.item, image, 'on a new body type')
    when PetType
      contributed_pet_type(contributed, image, :after => 'for the first time')
    when PetState
      contributed_pet_type(contributed.pet_type, image, :before => 'a new pose for')
    end
  end
  
  def contributed_item(item, image, adverbial)
    if item
      output do |html|
        html << 'the'
        html << link_to(item.name, item, :class => 'contributed-name')
        html << adverbial
        html << image_tag(item.thumbnail_url) if image
      end
    else
      "data for an item that has since been updated"
    end
  end
  
  PET_TYPE_IMAGE_FORMAT = 'http://pets.neopets.com/cp/%s/1/3.png'
  def contributed_pet_type(pet_type, image, options)
    options[:before] ||= 'the'
    output do |html|
      html << options[:before]
      html << content_tag(:span, pet_type.human_name, :class => 'contributed-name')
      html << options[:after] if options[:after]
      html << image_tag(sprintf(PET_TYPE_IMAGE_FORMAT, pet_type.image_hash)) if image
    end
  end
  
  private
  
  def output(&block)
    raw([].tap(&block).join(' '))
  end
end
