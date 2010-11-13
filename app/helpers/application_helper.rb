module ApplicationHelper
  def add_body_class(class_name)
    @body_class ||= ''
    @body_class << " #{class_name}"
  end
  
  def auth_server_icon_url
    "http://#{Openneo::Auth.config.auth_server}/favicon.png"
  end
  
  def body_class
    "#{params[:controller]} #{params[:controller]}-#{params[:action]}".tap do |output|
      output << @body_class if @body_class
    end
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
    :jquery => 'http://ajax.googleapis.com/ajax/libs/jquery/1.4.3/jquery.min.js',
    :jquery_tmpl => 'http://ajax.microsoft.com/ajax/jquery.templates/beta1/jquery.tmpl.min.js',
    :swfobject => 'http://ajax.googleapis.com/ajax/libs/swfobject/2.2/swfobject.js'
  }
  
  def include_javascript_libraries(*library_names)
    raw(library_names.inject('') do |html, name|
      html + javascript_include_tag(JAVASCRIPT_LIBRARIES[name])
    end)
  end
  
  def login_path_with_return_to
    login_path :return_to => request.fullpath
  end
  
  def logout_path_with_return_to
    logout_path :return_to => request.fullpath
  end
  
  def origin_tag(value)
    hidden_field_tag 'origin', value, :id => nil
  end
  
  def signed_in_meta_tag
    %(<meta name="user-signed-in" content="#{user_signed_in?}">).html_safe
  end
  
  def title(value)
    content_for :title, value
  end
end
