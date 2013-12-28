module ItemsHelper
  JNItemsURLFormat = 'http://items.jellyneo.net/index.php?go=show_items&name=%s&name_type=exact'
  
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
    build_on_pet_types(Species.alphabetical) do |pet_type|
      image = pet_type_image(pet_type, :happy, :zoom)
      query = "species:#{pet_type.species.name}"
      link_to(image, items_path(:q => query))
    end
  end

  def standard_species_images_for(pet_types_by_species_id)
    pet_types_by_species_id.to_a.sort_by { |s, pt| s.name }.map { |species, pet_types|
      pet_type_images = pet_types.map { |pet_type|
        image = pet_type_image(pet_type, :happy, :face)
        content_tag(:li, image, 'class' => 'pet-type',
                                'data-id' => pet_type.id,
                                'data-body-id' => pet_type.body_id,
                                'data-color-id' => pet_type.color.id,
                                'data-color-name' => pet_type.color.name,
                                'data-species-id' => pet_type.species.id,
                                'data-species-name' => pet_type.species.name)
      }.join.html_safe
      content_tag(:li, content_tag(:ul, pet_type_images),
                  'data-id' => species.id)
    }.join.html_safe
  end
  
  def closet_list_verb(owned)
    ClosetHanger.verb(:you, owned)
  end
  
  def owned_icon
    image_tag 'owned.png', :title => t('items.item.owned.description'),
              :alt => t('items.item.owned.abbr')
  end
  
  def wanted_icon
    image_tag 'wanted.png', :title => t('items.item.wanted.description'),
              :alt => t('items.item.wanted.abbr')
  end

  def closeted_icons_for(item)
    content = ''.html_safe

    content << owned_icon if item.owned?
    content << wanted_icon if item.wanted?

    content_tag :div, content, :class => 'closeted-icons'
  end

  def list_zones(zones, method=:label)
    zones.map(&method).join(', ')
  end
  
  def nc_icon
    image_tag 'nc.png', :title => t('items.item.nc.description'),
              :alt => t('items.item.nc.abbr'), :class => 'nc-icon'
  end

  def nc_icon_for(item)
    nc_icon if item.nc?
  end

  def jn_items_url_for(item)
    sprintf(JNItemsURLFormat, CGI::escape(item.name))
  end
  
  def shop_wizard_url_for(item)
    "http://www.neopets.com/market.phtml?type=wizard&string=#{CGI::escape item.name}"
  end
  
  def super_shop_wizard_url_for(item)
    "http://www.neopets.com/portal/supershopwiz.phtml?string=#{CGI::escape item.name}"
  end
  
  def trading_post_url_for(item)
    "http://www.neopets.com/island/tradingpost.phtml?type=browse&criteria=item_exact&search_string=#{CGI::escape item.name}"
  end
  
  def auction_genie_url_for(item)
    "http://www.neopets.com/genie.phtml?type=process_genie&criteria=exact&auctiongenie=#{CGI::escape item.name}"
  end
  
  def trading_closet_hangers_header(owned, count)
    ownership_key = owned ? 'owned' : 'wanted'
    translate ".trading_closet_hangers.header.#{ownership_key}", :count => count
  end

  def render_trading_closet_hangers(owned)
    @trading_closet_hangers_by_owned[owned].map do |hanger|
      link_to hanger.user.name, user_closet_hangers_path(hanger.user)
    end.to_sentence.html_safe
  end
  
  def format_contribution_count(count)
    " (&times;#{count})".html_safe if count > 1
  end

  def render_item_link(item)
    # I've discovered that checking the cache *before* attempting to render the
    # partial is significantly faster: moving the cache line out here instead
    # of having it wrap the partial's content speeds up closet_hangers#index
    # rendering time by about a factor of 2. It's uglier, but this call happens
    # a lot, so the performance gain is definitely worth it. I'd be interested
    # in a more legit partial caching abstraction, but, for now, this will do.
    # Because this is a returned-string helper, but uses a buffer-output
    # helper, we have to do some indirection. Fake that the render is in a
    # template, then capture the resulting buffer output.
    capture do
      # Try to read from the prepared proxy's known partial output, if it's
      # even a proxy at all.
      if item.respond_to?(:known_partial_output)
        prepared_output = item.known_partial_output(:item_link_partial).try(:html_safe)
      else
        prepared_output = nil
      end
      prepared_output || localized_cache("items/#{item.id}#item_link_partial") do
        safe_concat render(partial: 'items/item_link', locals: {item: item})
      end
    end
  end

  private

  def build_on_pet_types(species, special_color=nil, &block)
    species_ids = species.map(&:id)
    pet_types = special_color ?
      PetType.where(:color_id => special_color.id, :species_id => species_ids).
        order(:species_id).includes_child_translations :
      PetType.random_basic_per_species(species.map(&:id))
    pet_types.map(&block).join.html_safe
  end

  def pet_type_image(pet_type, emotion, size)
    emotion_id = PetTypeImage::Emotions[emotion]
    size_id = PetTypeImage::Sizes[size]
    src = sprintf(PetTypeImage::Format, pet_type.basic_image_hash, emotion_id, size_id)
    human_name = pet_type.species.name.humanize
    image_tag(src, :alt => human_name, :title => human_name)
  end
end

