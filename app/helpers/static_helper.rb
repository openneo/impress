module StaticHelper
  def pledgie_link(options={})
    options[:class] ||= "pledgie-link"
    link_to 'Donate now!', pledgie_url, options
  end

  def pledgie_url
    "http://pledgie.com/campaigns/#{PLEDGIE_CAMPAIGN_ID}"
  end
end

