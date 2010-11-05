module ApplicationHelper
  def auth_server_icon_url
    # TODO: if auth servers expand, don't hardcode path
    URI::HTTP.build(
      :host => Openneo::Auth.config.auth_server,
      :path => '/favicon.png'
    ).to_s
  end
  
  def body_class
    "#{params[:controller]} #{params[:controller]}-#{params[:action]}"
  end
  
  def flashes
    raw(flash.inject('') do |html, pair|
      key, value = pair
      html + content_tag('p', value, :class => key)
    end)
  end
  
  JAVASCRIPT_LIBRARIES = {
    :addthis => 'http://s7.addthis.com/js/250/addthis_widget.js#username=openneo',
    :bitly => 'http://bit.ly/javascript-api.js?version=latest&login=openneo&apiKey=R_4d0438829b7a99860de1d3edf55d8dc8',
    :html5 => 'http://html5shim.googlecode.com/svn/trunk/html5.js',
    :jquery => 'http://ajax.googleapis.com/ajax/libs/jquery/1.4.0/jquery.min.js',
    :swfobject => 'http://ajax.googleapis.com/ajax/libs/swfobject/2.2/swfobject.js'
  }
  
  def include_javascript_libraries(*library_names)
    raw(library_names.inject('') do |html, name|
      html + javascript_include_tag(JAVASCRIPT_LIBRARIES[name])
    end)
  end
  
  def login_path_with_return_to
    login_path :return_to => request.request_uri
  end
end
