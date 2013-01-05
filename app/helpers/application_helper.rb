module ApplicationHelper
  include FragmentLocalization
  
  def absolute_url(path_or_url)
    if path_or_url.include?('://') # already an absolute URL
      path_or_url
    else # a relative path
      request.protocol + request.host_with_port + path_or_url
    end
  end
  
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

  CAMPAIGN_ACTIVE = false
  def campaign_progress(options={}, &block)
    if CAMPAIGN_ACTIVE || options[:always]
      include_campaign_progress_requirements

      if block_given?
        content = capture(&block)
      else
        content = link_to('We made it! Image Mode has been released.', donate_path) +
          link_to('Read more', donate_path, :class => 'button')
      end

      html = content_tag(:div, nil, :class => 'campaign-progress') +
        content_tag(:div, content, :class => 'campaign-progress-label')
      content_tag(:div, html, :class => 'campaign-progress-wrapper')
    end
  end

  def canonical_path(resource)
    content_for :meta, tag(:link, :rel => 'canonical', :href => url_for(resource))
  end

  def contact_email
    "webmaster@openneo.net"
  end

  def feedback_url
    "http://openneo.uservoice.com/forums/40720-dress-to-impress"
  end

  def flashes
    raw(flash.inject('') do |html, pair|
      key, value = pair
      html + content_tag('p', value, :class => "flash #{key}")
    end)
  end

  def include_campaign_progress_requirements
    unless @included_campaign_progress_requirements
      content_for(:javascripts,
        include_javascript_libraries(:jquery) +
          javascript_include_tag('pledgie')
      )

      content_for(:meta,
        tag(:meta, :name => 'pledgie-campaign-id', :content => PLEDGIE_CAMPAIGN_ID)
      )

      @included_campaign_progress_requirements = true
    end
  end

  def hide_home_link
    @hide_home_link = true
  end

  def home_link?
    !@hide_home_link
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
  
  def localized_cache(key={}, &block)
    localized_key = localize_fragment_key(key, locale)
    cache(localized_key, &block)
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
  
  def open_graph(properties)
    if @open_graph
      @open_graph.merge! properties
    else
      @open_graph = properties
    end
  end
  
  def open_graph_tags
    if @open_graph
      @open_graph.inject('') do |output, property|
        key, value = property
        output + tag(:meta, :property => "og:#{key}", :content => value)
      end.html_safe
    end
  end

  def return_to_field_tag
    hidden_field_tag :return_to, request.fullpath
  end
  
  def safely_to_json(obj)
    obj.to_json.gsub('/', '\/')
  end

  def secondary_nav(&block)
    content_for :before_flashes,
      content_tag(:nav, :id => 'secondary-nav', &block)
  end

  def show_title_header?
    params[:controller] != 'items'
  end

  def signed_in_meta_tag
    %(<meta name="user-signed-in" content="#{user_signed_in?}">).html_safe
  end
  
  def labeled_time_ago_in_words(time)
    content_tag :abbr, time_ago_in_words(time), :title => time
  end

  def title(value)
    content_for :title, value
  end
  
  def translate_markdown(key, options={})
    RDiscount.new(translate(key, options)).to_html.html_safe
  end
  
  alias_method :tmd, :translate_markdown
  
  def translate_with_links(key, options={})
    nonlink_options = {}
    link_urls = {}
    
    options.each do |key, value|
      str_key = key.to_s
      if str_key.end_with? '_link_url'
        link_key = str_key[0..-5] # "abcdef_link_url" => "abcdef_link"
        link_urls[link_key] = value
      else
        nonlink_options[key] = value
      end
    end
    
    link_options = {}
    link_urls.each do |link_key, url|
      content = translate("#{key}.#{link_key}_content", nonlink_options)
      link_options[link_key.to_sym] = link_to(content, url)
    end
    
    converted_options = link_options.merge(nonlink_options)
    translate("#{key}.main_html", converted_options)
  end
  
  alias_method :twl, :translate_with_links
  
  def userbar_contributions_summary(user)
    contributions_link_content = translate('.userbar.contributions_link_content',
                                           :user_points => user.points)
    contributions_link = link_to(contributions_link_content,
                                 user_contributions_path(user))
    translate '.userbar.contributions_summary_html',
              :contributions_link => contributions_link
  end
end

