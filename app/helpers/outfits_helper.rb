module OutfitsHelper
  def destination_tag(value)
    hidden_field_tag 'destination', value, :id => nil
  end

  def link_to_edit_outfit(content_or_outfit, outfit_or_options, options={})
    if block_given?
      content = capture_haml(&Proc.new)
      outfit = content_or_outfit
      options = outfit_or_options
    else
      content = content_or_outfit
      outfit = outfit_or_options
    end
    query = outfit.to_query
    query << "&outfit=#{outfit.id}" if user_signed_in? && outfit.user == current_user
    link_to content, wardrobe_path(:anchor => query), options
  end

  def outfit_li_for(outfit)
    class_name = outfit.starred? ? 'starred' : nil
    content_tag :li, :class => class_name, &Proc.new
  end

  def pet_attribute_select(name, collection, value=nil)
    select_tag name,
      options_from_collection_for_select(collection, :id, :human_name, value)
  end

  def pet_name_tag(options={})
    options = {:spellcheck => false, :id => nil}.merge(options)
    text_field_tag 'name', nil, options
  end
end

