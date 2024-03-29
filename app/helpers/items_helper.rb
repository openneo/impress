module ItemsHelper
  JNItemsURLFormat = 'https://items.jellyneo.net/search/?name=%s&name_type=3'
  
  module PetTypeImage
    Format = 'https://pets.neopets.com/cp/%s/%i/%i.png'

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
    "https://www.neopets.com/market.phtml?type=wizard&string=#{CGI::escape item.name}"
  end
  
  def super_shop_wizard_url_for(item)
    "https://www.neopets.com/portal/supershopwiz.phtml?string=#{CGI::escape item.name}"
  end
  
  def trading_post_url_for(item)
    "https://www.neopets.com/island/tradingpost.phtml?type=browse&criteria=item_exact&search_string=#{CGI::escape item.name}"
  end
  
  def auction_genie_url_for(item)
    "https://www.neopets.com/genie.phtml?type=process_genie&criteria=exact&auctiongenie=#{CGI::escape item.name}"
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
    render(partial: 'items/item_link', locals: {item: item})
  end

  def nc_trade_value_updated_at_text(nc_trade_value)
    return nil if nc_trade_value.updated_at.nil?

    # Render both "[X] [days] ago", and also the exact date, only including the
    # year if it's not this same year.
    time_ago_str = time_ago_in_words nc_trade_value.updated_at
    date_str = nc_trade_value.updated_at.year != Date.today.year ?
      nc_trade_value.updated_at.strftime("%b %-d") :
      nc_trade_value.updated_at.strftime("%b %-d, %Y")

    "Last updated: #{date_str} (#{time_ago_str} ago)"
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

