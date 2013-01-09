module ClosetListsHelper
  def closet_list_delete_confirmation(closet_list)
    ownership_key = closet_list.hangers_owned? ? 'owned' : 'wanted'
    translate("closet_lists.closet_list.delete_confirmation.#{ownership_key}",
              :list_name => closet_list.name)
  end

  def closet_list_description_format(list)
    md = RDiscount.new(list.description)
    Sanitize.clean(md.to_html, Sanitize::Config::BASIC).html_safe
  end

  def hangers_owned_options
    [
      [closet_lists_group_name(:you, true), true],
      [closet_lists_group_name(:you, false), false]
    ]
  end

  def render_sorted_hangers(list, show_controls)
    render :partial => 'closet_hanger',
      :collection => list.hangers.sort { |x,y| x.item.name <=> y.item.name },
      :locals => {:show_controls => show_controls}
  end
end

