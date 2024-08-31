require "addressable/template"

module ItemsHelper
  module PetTypeImage
    Template = Addressable::Template.new(
      "https://pets.neopets.com/cp/{hash}/{emotion}/{size}.png"
    )

    Emotions = {
      happy: 1,
      sad: 2,
      angry: 3,
      ill: 4,
    }

    Sizes = {
      face: 1,
      thumb: 2,
      zoom: 3,
      full: 4,
      face_2x: 6,
    }
  end

  def pet_type_image_url(pet_type, emotion: :happy, size: :face)
    PetTypeImage::Template.expand(
      hash: pet_type.basic_image_hash || pet_type.image_hash,
      emotion: PetTypeImage::Emotions[emotion],
      size: PetTypeImage::Sizes[size],
    ).to_s
  end

  def standard_species_search_links
    all_species = Species.alphabetical.map(&:id)
    PetType.random_basic_per_species(all_species).map do |pet_type|
      image = pet_type_image(pet_type, :happy, :zoom)
      query = "species:#{pet_type.species.name}"
      link_to(image, items_path(:q => query))
    end.join.html_safe
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
  
  # NOTE: Changing this requires bumping the cache at `_closet_list.html.haml`!
  def nc_icon
    image_tag 'nc.png', :title => t('items.item.nc.description'),
              :alt => t('items.item.nc.abbr'), :class => 'nc-icon'
  end

  # NOTE: Changing this requires bumping the cache at `_closet_list.html.haml`!
  def nc_icon_for(item)
    nc_icon if item.nc?
  end

  # NOTE: Changing this requires bumping the cache at `_closet_list.html.haml`!
  def item_thumbnail_for(item)
    image_tag item.thumbnail_url, alt: "Thumbnail for #{item.name}",
      title: item.description, loading: "lazy"
  end

  def time_with_only_month_if_old(first_seen_at)
    # For this month and the previous month, show the full date, so people can
    # understand *exactly* how recent it was.
    beginning_of_prev_month = Date.today.beginning_of_month - 1.month
    if first_seen_at >= beginning_of_prev_month
      return first_seen_at.strftime("%b %e, %Y")
    end

    # Otherwise, show just the month and the year, to be concise. (We'll offer
    # the full date as a tooltip, too.)
    first_seen_at.strftime("%b %Y")
  end

  JN_ITEMS_URL_TEMPLATE = Addressable::Template.new(
    "https://items.jellyneo.net/search/?name_type=3{&name}"
  )
  def jn_items_url_for(item)
    JN_ITEMS_URL_TEMPLATE.expand(name: item.name).to_s
  end

  IMPRESS_2020_ITEM_URL_TEMPLATE = Addressable::Template.new(
    "#{Rails.configuration.impress_2020_origin}/items/{id}"
  )
  def impress_2020_url_for(item)
    IMPRESS_2020_ITEM_URL_TEMPLATE.expand(id: item.id).to_s
  end
  
  SHOP_WIZARD_URL_TEMPLATE = Addressable::Template.new(
    "https://www.neopets.com/shops/wizard.phtml{?string}"
  )
  def shop_wizard_url_for(item_or_name)
    item_or_name = item_or_name.name if item_or_name.is_a? Item
    SHOP_WIZARD_URL_TEMPLATE.expand(string: item_or_name).to_s
  end

  TRADING_POST_URL_TEMPLATE = Addressable::Template.new(
    "https://www.neopets.com/island/tradingpost.phtml?type=browse&criteria=item_exact{&search_string}"
  )
  def trading_post_url_for(item_or_name)
    item_or_name = item_or_name.name if item_or_name.is_a? Item
    TRADING_POST_URL_TEMPLATE.expand(search_string: item_or_name).to_s
  end
  
  AUCTION_GENIE_URL_TEMPLATE = Addressable::Template.new(
    "https://www.neopets.com/genie.phtml?type=process_genie&criteria=exact{&auctiongenie}"
  )
  def auction_genie_url_for(item)
    AUCTION_GENIE_URL_TEMPLATE.expand(auctiongenie: item.name).to_s
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

  NC_TRADE_VALUE_ESTIMATE_PATTERN = %r{
    \A\s*
    (?:
      # Case 1: A single number
      (?<single>[0-9]+)
      |
      # Case 2: A range from low to high
      (?<low>[0-9]+)
      \p{Dash_Punctuation}
      (?<high>[0-9]+)
    )
    \s*\z
  }x
  def nc_trade_value_is_estimate(nc_trade_value)
    nc_trade_value.value_text.match?(NC_TRADE_VALUE_ESTIMATE_PATTERN)
  end

  # Try to parse the NC trade value's text into something styled a bit more
  # nicely for our use case.
  def nc_trade_value_estimate_text(nc_trade_value)
    match = nc_trade_value.value_text.match(NC_TRADE_VALUE_ESTIMATE_PATTERN)
    return nc_trade_value if match.nil?

    match => {single:, low:, high:}
    if single.present?
      pluralize single.to_i, "capsule"
    elsif low.present? && high.present?
      "#{low}–#{high} capsules"
    else
      nc_trade_value
    end
  end

  def nc_total_for(items)
    items.map(&:current_nc_price).sum
  end

  def dyeworks_nc_total_for(items)
    nc_total_for items.map(&:dyeworks_base_item)
  end

  def dyeworks_average_num_potions_for(items)
    # Compute the number of expected potions for each (inverse of the odds),
    # sum them, then round up.
    items.map { |i| 1 / i.dyeworks_odds }.sum.ceil
  end

  def dyeworks_estimated_potions_cost_for(items)
    # NOTE: You could do bundles too, but let's just keep it simple.
    dyeworks_average_num_potions_for(items) * 125
  end

  def complexity_for(items)
    max_name_length = items.map(&:name).map(&:length).max
    max_name_length >= 40 ? "high" : "low"
  end

  def probability(p)
    case p
    when 1
      "100%"
    when 0
      "0%"
    else
      "#{p.numerator} in #{p.denominator}"
    end
  end

  def outfit_viewer_is_playing
    cookies["DTIOutfitViewerIsPlaying"] == "true"
  end

  private

  def pet_type_image(pet_type, emotion, size)
    src = pet_type_image_url(pet_type, emotion:, size:)
    human_name = pet_type.species.name.humanize
    image_tag(src, :alt => human_name, :title => human_name)
  end

  def item_header_user_lists_form_state
    cookies.fetch("DTIItemPageUserListsFormState", "closed")
  end
end

