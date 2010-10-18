module ApplicationHelper
  def auth_server_icon_url
    # TODO: if auth servers expand, don't hardcode path
    URI::HTTP.build(
      :host => Openneo::Auth.config.auth_server,
      :path => '/favicon.png'
    ).to_s
  end
  
  def flashes
    flash.inject('') do |html, pair|
      key, value = pair
      content_tag 'p', value, :class => key
    end
  end
end
