module OutfitsHelper
  def destination_tag(value)
    hidden_field_tag 'destination', value, :id => nil
  end
  
  def latest_contribution_description(contribution)
    user = contribution.user
    contributed = contribution.contributed
    t 'outfits.new.latest_contribution.description_html',
      :user_link => link_to(user.name, user_contributions_path(user)),
      :contributed_description => contributed_description(contributed, false)
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
    query << "&outfit=#{outfit.id}" if user_signed_in? && outfit.user_id == current_user.id
    link_to content, wardrobe_path(:anchor => query), options
  end
  
  def search_helper(filter, standard_key)
    key = translate("#{filter}.key")
    default_value = translate("#{filter}.default_value")
    content_tag :span, default_value, :class => 'search-helper',
                                      'data-search-filter-key' => standard_key,
                                      'data-search-filter-name' => key
  end
  
  def search_query_description(base, standard_key)
    translate "#{base}.description_html",
              :default_value => search_helper("#{base}.filter", standard_key)
  end
  
  def search_query_with_helper(base, standard_key)
    translate "#{base}.query_html",
              :filter_key => content_tag(:span, translate("#{base}.filter.key")),
              :filter_value => search_helper("#{base}.filter", standard_key)
  end
  
  def search_query(translation_key, filter_key)
    base = "outfits.edit.search.examples.#{translation_key}"
    content_tag(:dt, search_query_with_helper(base, filter_key)) +
      content_tag(:dd, search_query_description(base, filter_key))
  end

  def remote_load_pet_path
    "http://#{Rails.configuration.neopia_host}/api/1/pet/customization"
  end

  def render_predicted_missing_species_by_color(species_by_color)
    key_prefix = 'outfits.new.newest_items.unmodeled.content'

    # Transform the Color => (Species => Int) map into an Array<Pair<Color's
    # human name (empty if standard), (Species => Int)>>.
    standard = species_by_color.delete(:standard)
    sorted_pairs = species_by_color.to_a.map { |k, v| [k.human_name, v] }.
                                         sort_by { |k, v| k }
    sorted_pairs.unshift(['', standard]) if standard
    species_by_color[:standard] = standard # undo parameter mutation

    first = true
    contents = sorted_pairs.map { |color_human_name, body_ids_by_species|
      species_list = body_ids_by_species.keys.sort_by(&:human_name).map { |species|
        body_id = body_ids_by_species[species]
        content_tag(:span, species.human_name, 'data-body-id' => body_id)
      }.to_sentence(
        words_connector: t("#{key_prefix}.species_list.words_connector"),
        two_words_connector: t("#{key_prefix}.species_list.two_words_connector"),
        last_word_connector: t("#{key_prefix}.species_list.last_word_connector")
      )
      key = first ? 'first' : 'other'
      content = t("#{key_prefix}.body.#{key}", color: color_human_name,
                                               species_list: species_list).html_safe
      first = false
      content
    }
    contents.last << " " + t("#{key_prefix}.call_to_action")
    content_tags = contents.map { |c| content_tag(:p, c) }
    content_tags.join('').html_safe
  end
  
  def outfit_creation_summary(outfit)
    user = outfit.user
    user_link = link_to(user.name, user_contributions_path(user))
    created_at_ago = content_tag(:abbr, time_ago_in_words(@outfit.created_at),
                                 :title => @outfit.created_at)
    translate 'outfits.show.creation_summary_html',
      :user_link => user_link,
      :created_at_ago => created_at_ago
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

