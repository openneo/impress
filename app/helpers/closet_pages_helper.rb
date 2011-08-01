module ClosetPagesHelper
  def link_to_neopets_login(content)
    link_to content, neopets_login_url, :target => "_blank"
  end

  def neopets_login_url
    "http://www.neopets.com/loginpage.phtml"
  end
end

