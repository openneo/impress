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

  def body_class
    "#{params[:controller]} #{params[:controller]}-#{params[:action]}".tap do |output|
      output << @body_class if @body_class
    end
  end

  def advertise_campaign_progress(campaign, &block)
    if campaign && campaign.advertised?
      campaign_progress(campaign, &block)
    end
  end

  def cents_to_currency(cents, options={})
    number_to_currency(cents / 100.0, options)
  end

  def campaign_progress(campaign, &block)
    if campaign
      if block_given?
        content = capture(&block)
      else
        if campaign.complete?
          pitch = "We've met this year's fundraising goal! Thanks, everybody!"
          prompt = "Learn more"
        elsif campaign.remaining < 200_00
          estimate = (campaign.remaining.to_f / 10_00).ceil * 10_00
          if estimate == campaign.remaining
            pitch = "We're only #{cents_to_currency(estimate, precision: 0)} away from paying #{campaign.purpose}!"
          else
            pitch = "We're less than #{cents_to_currency(estimate, precision: 0)} away from paying #{campaign.purpose}!"
          end
          prompt = "Donate now"
        else
          pitch = "Help Dress to Impress stay online!"
          prompt = "Learn more"
        end
        content = link_to(
          content_tag(:span, pitch) +
          content_tag(:span, prompt, :class => 'button'), donate_path)
      end

      meter = content_tag(:div, nil, :class => 'campaign-progress',
        style: "width: #{campaign.progress_percent}%;")
      label = content_tag(:div, content, :class => 'campaign-progress-label')
      content_tag(:div, meter + label, :class => 'campaign-progress-wrapper')
    end
  end

  def canonical_path(resource)
    I18n.with_locale(I18n.default_locale) do
      content_for :meta, tag(:link, :rel => 'canonical', :href => url_for(resource))
    end
  end

  def contact_email
    "webmaster@openneo.net"
  end

  def feedback_url
    "https://openneo.uservoice.com/forums/40720-dress-to-impress"
  end

  def flashes
    raw(flash.inject('') do |html, pair|
      key, value = pair
      html + content_tag('p', value, :class => "flash #{key}")
    end)
  end

  def hide_home_link
    @hide_home_link = true
  end

  def home_link?
    !@hide_home_link
  end

  JAVASCRIPT_LIBRARIES = {
    :addthis => '//s7.addthis.com/js/250/addthis_widget.js#username=openneo',
    :bitly => '//bit.ly/javascript-api.js?version=latest&login=openneo&apiKey=R_4d0438829b7a99860de1d3edf55d8dc8',
    :html5 => '//html5shim.googlecode.com/svn/trunk/html5.js',
    :jquery => '//ajax.googleapis.com/ajax/libs/jquery/1.4.3/jquery.min.js',
    :jquery20 => '//ajax.googleapis.com/ajax/libs/jquery/2.0.3/jquery.min.js',
    :jquery_tmpl => '//ajax.microsoft.com/ajax/jquery.templates/beta1/jquery.tmpl.min.js',
    :swfobject => '//ajax.googleapis.com/ajax/libs/swfobject/2.2/swfobject.js'
  }

  def include_javascript_libraries(*library_names)
    raw(library_names.inject('') do |html, name|
      html + javascript_include_tag(JAVASCRIPT_LIBRARIES[name])
    end)
  end
  
  def locale_options
    current_locale_is_public = false
    options = I18n.public_locales.map do |available_locale|
      current_locale_is_public = true if I18n.locale == available_locale
      # Include fallbacks data on the tag. Right now it's used in blog
      # localization, but may conceivably be used for something else later.
      [translate('locale_name', :locale => available_locale), available_locale,
       {'data-fallbacks' => I18n.fallbacks[available_locale].join(',')}]
    end
    
    unless current_locale_is_public
      name = translate('locale_name', :locale => I18n.locale) + ' (alpha)'
      options << [name, I18n.locale]
    end
    
    options
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

  def current_user_id_meta_tag
    %(<meta name="current-user-id" content="#{current_user.id}">).html_safe
  end
  
  def labeled_time_ago_in_words(time)
    content_tag :abbr, time_ago_in_words(time), :title => time
  end

  def title(value)
    content_for :title, value
  end

  def md(text)
    RDiscount.new(text).to_html.html_safe
  end
  
  def translate_markdown(key, options={})
    md translate("#{key}_markdown", options)
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
    translate_with_links '.userbar.contributions_summary',
      :contributions_link_url => user_contributions_path(user),
      :user_points => user.points
  end

  def camo_image_url(image_url)
    Image.from_insecure_url(image_url).secure_url
  end
end

