require 'cgi'

module ClosetHangersHelper
  def closet_hanger_verb(owned, positive=true)
    ClosetHanger.verb(closet_hanger_subject, owned, positive)
  end

  def send_neomail_url(user)
    "http://www.neopets.com/neomessages.phtml?type=send&recipient=#{CGI.escape @user.neopets_username}"
  end

  def closet_hanger_subject
    public_perspective? ? @user.name : :you
  end

  def public_perspective?
    @public_perspective
  end

  def render_closet_hangers(owned)
    render :partial => 'closet_hanger',
      :collection => @closet_hangers_by_owned[owned],
      :locals => {:show_controls => !public_perspective?}
  end
end

