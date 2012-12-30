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
    build_on_pet_types(Species.all) do |pet_type|
      image = pet_type_image(pet_type, :happy, :zoom)
      query = "species:#{pet_type.species.name}"
      link_to(image, items_path(:q => query))
    end
  end

  def standard_species_images_for(item)
    build_on_pet_types(item.supported_species, item.special_color) do |pet_type|
      image = pet_type_image(pet_type, :happy, :face)
      attributes = {
        'data-id' => pet_type.id,
        'data-body-id' => pet_type.body_id
      }
      [:color, :species].each do |pet_type_attribute_name|
        pet_type_attribute = pet_type.send(pet_type_attribute_name)
        [:id, :name].each do |subattribute_name|
          attributes["data-#{pet_type_attribute_name}-#{subattribute_name}"] =
            pet_type_attribute.send(subattribute_name)
        end
      end
      link_to(
        image,
        '#',
        attributes
      )
    end
  end
  
  def closet_list_verb(owned)
    ClosetHanger.verb(:you, owned)
  end
  
  def owned_icon
    image_tag 'owned.png', :title => 'You own this', :alt => 'Own'
  end
  
  def wanted_icon
    image_tag 'wanted.png', :title => 'You want this', :alt => 'Want'
  end

  def closeted_icons_for(item)
    content = ''.html_safe

    content << owned_icon if item.owned?
    content << wanted_icon if item.wanted?

    content_tag :div, content, :class => 'closeted-icons'
  end

  def list_zones(zones, method=:label)
    zones.sort { |x,y| x.label <=> y.label }.map(&method).join(', ')
  end
  
  def nc_icon
    image_tag 'nc.png', :title => 'NC Mall Item', :alt => 'NC',
              :class => 'nc-icon'
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

  private

  def build_on_pet_types(species, special_color=nil, &block)
    species_ids = species.map(&:id)
    pet_types = special_color ?
      PetType.where(:color_id => special_color.id, :species_id => species_ids).order(:species_id) :
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

