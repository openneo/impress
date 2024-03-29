require 'cgi'

module ClosetHangersHelper
  def closet_hangers_help_class(user)
    'hidden' unless user.closet_hangers.empty?
  end

  def closet_hanger_partial_class(hanger)
    'object'.tap do |class_name|
      class_name << ' user-owns' if hanger.item.owned?
      class_name << ' user-wants' if hanger.item.wanted?
    end
  end

  def send_neomail_url(neopets_username)
    "https://www.neopets.com/neomessages.phtml?type=send&recipient=#{CGI.escape neopets_username}"
  end

  def neopets_lookup_url(neopets_username)
    "https://www.neopets.com/userlookup.phtml?user=#{CGI.escape neopets_username}"
  end

  def hangers_group_visibility_field_name(owned)
    owned ? :owned_closet_hangers_visibility : :wanted_closet_hangers_visibility
  end

  def closet_visibility_choices(*args)
    ClosetVisibility.levels.map do |level|
      [level.send(*args), level.id]
    end
  end

  def closet_visibility_descriptions(subject=:items)
    content = ''
    ClosetVisibility.levels.each do |level|
      content << content_tag(:li, level.description(subject), 'data-id' => level.id)
    end
    content_tag :ul, content.html_safe, :class => 'visibility-descriptions'
  end

  # Do we have either unlisted hangers that are owned/wanted, or non-empty
  # owned/wanted lists?
  def has_hangers?(owned)
    # If we have unlisted hangers of this type, pass.
    return true if @unlisted_closet_hangers_by_owned.has_key?(owned)

    # Additionally, if we have no lists of this type, fail.
    lists = @closet_lists_by_owned[owned]
    return false unless lists

    # If any of those lists are non-empty, pass.
    lists.each do |list|
      return true unless list.hangers.empty?
    end

    # Otherwise, all of the lists are empty. Fail.
    return false
  end

  def has_lists?(owned)
    @closet_lists_by_owned.has_key?(owned)
  end

  def link_to_add_closet_list(content, options)
    owned = options.delete(:owned)
    path = new_user_closet_list_path current_user,
      :closet_list => {:hangers_owned => owned}
    link_to(content, path, options)
  end
  
  def long_closet_visibility_choices(subject)
    ClosetVisibility.levels.map do |level|
      ["#{level.human_name}: #{level.description(subject)}", level.id]
    end
  end

  def nc_icon_url
    "https://#{request.host}#{image_path 'nc.png'}"
  end
  
  def petpage_closet_list_checked(closet_list, owned)
    @visible_closet_lists_by_owned.has_key?(owned) &&
      @visible_closet_lists_by_owned[owned].include?(closet_list)
  end
  
  def petpage_group_checked(owned)
    @visible_groups.include?(owned)
  end

  def petpage_item_name(item)
    item.name.gsub(/ On/i, ' O<b></b>n').html_safe
  end

  PETPAGE_IMAGE_URL_BLACKLIST = %w(window. ondrop)
  def petpage_item_thumbnail_url(item)
    url = item.thumbnail_url

    # If the URL includes any of the blacklisted terms, use our redirect URL
    PETPAGE_IMAGE_URL_BLACKLIST.each do |term|
      if url.include?(term)
        url = item_url(item, :format => :gif)
        break
      end
    end

    url
  end

  def public_perspective?
    @public_perspective
  end

  PETPAGE_HANGER_BATCH_SIZE = 5
  def render_batched_petpage_hangers(hangers)
    output do |html|
      hangers.in_groups_of(PETPAGE_HANGER_BATCH_SIZE) do |batch|
        content = batch.map do |hanger|
          render 'petpage_hanger', :hanger => hanger if hanger
        end.join.html_safe
        html << content_tag(:div, content, :class => 'dti-item-row')
      end
    end
  end

  def render_closet_lists(lists)
    if lists
      render :partial => 'closet_lists/closet_list', :collection => lists,
        :locals => {:show_controls => !public_perspective?}
    end
  end

  def render_unlisted_closet_hangers(owned)
    hangers_content = render :partial => 'closet_hanger',
      :collection => @unlisted_closet_hangers_by_owned[owned],
      :locals => {:show_controls => !public_perspective?}
  end

  def unlisted_hangers_count(owned)
    hangers = @unlisted_closet_hangers_by_owned[owned]
    hangers ? hangers.size : 0
  end
  
  def closet_lists_group_name(subject, owned)
    ownership_key = owned ? 'owned_by' : 'wanted_by'
    if subject == :you
      translate "closet_lists.groups.#{ownership_key}.you"
    else
      translate "closet_lists.groups.#{ownership_key}.another_user",
        :user_name => subject
    end
  end
  
  def closet_hangers_subject(user)
    public_perspective? ? user.name : :you
  end

  def destination_options
    # eww, copy-pasted from neopets page import helpers
    options = []
    [true, false].each do |owned|
      relevant_lists = @closet_lists_by_owned[owned] || []
      options << [closet_lists_group_name(:you, owned), owned]
      options += relevant_lists.map { |list| ["&mdash;#{h list.name}".html_safe, list.id] }
    end
    options
  end
end

