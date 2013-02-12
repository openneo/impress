module ContributionHelper
  def contributed_description(contributed, show_image = true)
    case contributed
    when Item
      contributed_item('item', contributed, show_image)
    when SwfAsset
      contributed_item('swf_asset', contributed.item, show_image)
    when PetType
      contributed_pet_type('pet_type', contributed, show_image)
    when PetState
      contributed_pet_type('pet_state', contributed.pet_type, show_image)
    end
  end
  
  def contributed_item(main_key, item, show_image)
    if item
      link = link_to(item.name, item, :class => 'contributed-name')
      description = translate('contributions.contributed_description.parents.item.present_html',
                              :item_link => link)
      output = translate("contributions.contributed_description.main.#{main_key}_html",
                         :item_description => description)
      output << image_tag(item.thumbnail_url) if show_image
      output
    else
      translate('contributions.contributed_description.parents.item.blank')
    end
  end
  
  PET_TYPE_IMAGE_FORMAT = 'http://pets.neopets.com/cp/%s/1/3.png'
  def contributed_pet_type(main_key, pet_type, show_image)
    span = content_tag(:span, pet_type.human_name, :class => 'contributed-name')
    description = translate('contributions.contributed_description.parents.pet_type_html',
                            :pet_type_name => span)
    output = translate("contributions.contributed_description.main.#{main_key}_html",
                       :pet_type_description => description)
    output << image_tag(sprintf(PET_TYPE_IMAGE_FORMAT, pet_type.image_hash)) if show_image
    output
  end
  
  private
  
  def output(&block)
    raw([].tap(&block).join(' '))
  end
  
  def translate_contributed_suffix(key)
    translate "contributions.contributed_description.suffix.#{key}"
  end
end
