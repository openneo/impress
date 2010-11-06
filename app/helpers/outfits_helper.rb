module OutfitsHelper
  def destination_tag(value)
    hidden_field_tag 'destination', value, :id => nil
  end
  
  def pet_attribute_select(name, collection, value=nil)
    select_tag name,
      options_from_collection_for_select(collection, :id, :human_name, value)
  end
  
  def pet_name_tag
    text_field_tag 'name', nil, :spellcheck => false, :id => nil
  end
end
