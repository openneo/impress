module ContributionHelper
  def contributed_description(contributed)
    case contributed
    when Item
      contributed_item(contributed, 'for the first time')
    when SwfAsset
      contributed_item(contributed.item, 'on a new body type')
    when PetType
      contributed_pet_type(contributed, :after => 'for the first time')
    when PetState
      contributed_pet_type(contributed.pet_type, :before => 'a new pose for')
    end
  end
  
  def contributed_item(item, adverbial)
    if item
      output do |html|
        html << 'the'
        html << link_to(item.name, item, :class => 'contributed-name')
        html << adverbial
        html << image_tag(item.thumbnail_url)
      end
    else
      "data for an item that has since been updated"
    end
  end
  
  PET_TYPE_IMAGE_FORMAT = 'http://pets.neopets.com/cp/%s/1/3.png'
  def contributed_pet_type(pet_type, options)
    options[:before] ||= 'the'
    output do |html|
      html << options[:before]
      html << content_tag(:span, pet_type.human_name, :class => 'contributed-name')
      html << options[:after] if options[:after]
      html << image_tag(sprintf(PET_TYPE_IMAGE_FORMAT, pet_type.image_hash))
    end
  end
  
  private
  
  def output(&block)
    raw([].tap(&block).join(' '))
  end
end
