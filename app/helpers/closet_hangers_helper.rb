require 'cgi'

module ClosetHangersHelper
  def send_neomail_url(user)
    "http://www.neopets.com/neomessages.phtml?type=send&recipient=#{CGI.escape @user.neopets_username}"
  end

  def public_perspective?
    @public_perspective
  end
end

