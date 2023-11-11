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

  def outfit_li_for(outfit, &block)
    class_name = outfit.starred? ? 'starred' : nil
    content_tag :li, :class => class_name, &block
  end

  def pet_attribute_select(name, collection, value=nil)
    options = options_from_collection_for_select(collection, :id, :human_name, value)
    select_tag name, options, id: nil, class: name
  end

  def pet_name_tag(options={})
    options = {:spellcheck => false, :id => nil}.merge(options)
    text_field_tag 'name', nil, options
  end
end

