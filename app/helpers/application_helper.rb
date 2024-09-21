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
    controller = params[:controller].gsub("/", "-")
    "#{controller} #{controller}-#{params[:action]}".tap do |output|
      output << @body_class if @body_class
    end
  end

  def button_link_to(content_or_url, url = nil, icon: nil, **options)
    if url.present?
      content = content_or_url
      url = url
    else
      content = nil
      url = content_or_url
    end

    klass = options.fetch(:class, "") + " button"
    link_to url, class: klass, **options do
      concat icon
      concat " "
      if block_given?
        yield
      else
        concat content
      end
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

  # SVG icon source from Font Awesome 6! (https://creativecommons.org/licenses/by/4.0/)
  CART_ICON_SVG_SOURCE = '<path fill="currentColor" d="M0 24C0 10.7 10.7 0 24 0H69.5c22 0 41.5 12.8 50.6 32h411c26.3 0 45.5 25 38.6 50.4l-41 152.3c-8.5 31.4-37 53.3-69.5 53.3H170.7l5.4 28.5c2.2 11.3 12.1 19.5 23.6 19.5H488c13.3 0 24 10.7 24 24s-10.7 24-24 24H199.7c-34.6 0-64.3-24.6-70.7-58.5L77.4 54.5c-.7-3.8-4-6.5-7.9-6.5H24C10.7 48 0 37.3 0 24zM128 464a48 48 0 1 1 96 0 48 48 0 1 1 -96 0zm336-48a48 48 0 1 1 0 96 48 48 0 1 1 0-96z"></path>'.html_safe
  def cart_icon(alt: "Cart")
    content_tag :svg, CART_ICON_SVG_SOURCE, alt:, class: "icon",
      viewBox: "0 0 576 512", style: "height: 1em"
  end

  def contact_email
    "matchu@openneo.net"
  end

  EDIT_ICON_SVG_SOURCE = '<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></g>'.html_safe
  def edit_icon(alt: "Edit")
    content_tag :svg, EDIT_ICON_SVG_SOURCE, alt:, class: "icon",
      viewBox: "0 0 24 24", style: "width: 1em; height: 1em"
  end

  # SVG icon source from Chakra UI!
  EXTERNAL_LINK_SVG_SOURCE = '<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"></path><path d="M15 3h6v6"></path><path d="M10 14L21 3"></path></g>'.html_safe
  def external_link_icon
    content_tag :svg, EXTERNAL_LINK_SVG_SOURCE, alt: "(external link)",
      class: "icon", viewBox: "0 0 24 24", style: "width: 1em; height: 1em"
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

  def support_staff?
    user_signed_in? && current_user.support_staff?
  end

  def impress_2020_meta_tags
    origin = Rails.configuration.impress_2020_origin
    support_secret = Rails.application.credentials.dig(
      :impress_2020, :support_secret)

    capture do
      concat tag("meta", name: "impress-2020-origin", content: origin)

      if support_staff? && support_secret.present?
        concat tag("meta", name: "impress-2020-support-secret",
          content: support_secret)
      end
    end
  end

  def locale_options
    current_locale_is_public = false
    options = I18n.available_locales.map do |available_locale|
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
    # TODO: The digest feature is handy, but it's not compatible with how we
    # check for fragments existence in the controller, so skip it for now.
    cache(localized_key, skip_digest: true, &block)
  end

  def auth_user_sign_in_path_with_return_to
    new_auth_user_session_path :return_to => request.fullpath
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

  # Includes a stylesheet designed for this specific page of the app, which
  # should be removed when navigating to another page. We use Turbo's
  # `data-turbo-track="dynamic"` option to do this.
  def page_stylesheet_link_tag(src, options={})
    options = {data: {"turbo-track": "dynamic"}}.deep_merge(options)
    stylesheet_link_tag src, options
  end

  # SVG icon source from Chakra UI!
  SEARCH_SVG_SOURCE = '<path fill="currentColor" d="M23.384,21.619,16.855,15.09a9.284,9.284,0,1,0-1.768,1.768l6.529,6.529a1.266,1.266,0,0,0,1.768,0A1.251,1.251,0,0,0,23.384,21.619ZM2.75,9.5a6.75,6.75,0,1,1,6.75,6.75A6.758,6.758,0,0,1,2.75,9.5Z"></path>'.html_safe
  def search_icon
    content_tag :svg, SEARCH_SVG_SOURCE, alt: "Search", class: "icon",
      viewBox: "0 0 24 24", style: "width: 1em; height: 1em"
  end

  def secondary_nav(&block)
    content_for :before_flashes,
      content_tag(:nav, :id => 'secondary-nav', &block)
  end

  def show_title_header?
    params[:controller] != 'items' && !@hide_title_header
  end

  def hide_title_header
    @hide_title_header = true
  end

  def use_responsive_design
    @use_responsive_design = true
    add_body_class "use-responsive-design"
  end

  def use_responsive_design?
    @use_responsive_design || false
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

  def terms_updated_at
    Date.new(2024, 2, 29)
  end

  def terms_updated_timestamp
    terms_updated_at.strftime("%b %Y")
  end

  def terms_updated_recently
    terms_updated_at >= 2.months.ago
  end
  
  def translate_markdown(key, options={})
    md translate("#{key}_markdown", **options)
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
      content = translate("#{key}.#{link_key}_content", **nonlink_options)
      link_options[link_key.to_sym] = link_to(content, url)
    end
    
    converted_options = link_options.merge(nonlink_options)
    translate("#{key}.main_html", **converted_options)
  end
  
  alias_method :twl, :translate_with_links
  
  def userbar_contributions_summary(user)
    translate_with_links '.userbar.contributions_summary',
      :contributions_link_url => user_contributions_path(user),
      :user_points => user.points
  end
end

