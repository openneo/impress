module ClosetListsHelper
  def closet_list_delete_confirmation(closet_list)
    "Are you sure you want to delete \"#{closet_list.name}\"?".tap do |msg|
      unless closet_list.hangers.empty?
        msg << " Even if you do, we'll remember that you " +
          ClosetHanger.verb(:you, closet_list.hangers_owned) +
          " these items."
      end
    end
  end

  def closet_list_description_format(list)
    md = RDiscount.new(list.description)
    Sanitize.clean(md.to_html, Sanitize::Config::BASIC).html_safe
  end

  def hangers_owned_options
    @hangers_owned_options ||= [true, false].map do |owned|
      verb = ClosetHanger.verb(:i, owned)
      ["items I #{verb}", owned]
    end
  end

  def render_sorted_hangers(list, show_controls)
    render :partial => 'closet_hanger',
      :collection => list.hangers.sort { |x,y| x.item.name <=> y.item.name },
      :locals => {:show_controls => show_controls}
  end
end

