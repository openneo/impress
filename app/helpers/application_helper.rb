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
  
  def hide_home_link
    @hide_home_link = true
  end
  
  def home_link?
    !@hide_home_link
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
