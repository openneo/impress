module StaticHelper
  def pledgie_amount_label_tag(content)
    label_tag 'pledge[amount]', content
  end

  def pledgie_amount_field_tag(amount)
    text_field_tag 'pledge[amount]', amount, :id => 'pledge_amount'
  end

  def pledgie_confirm_url
    "http://pledgie.com/campaigns/#{PLEDGIE_CAMPAIGN_ID}/pledge/confirm"
  end

  def pledgie_form_tag(*args, &block)
    form_tag(pledgie_confirm_url, *args, &block)
  end

  def pledgie_url
    "http://pledgie.com/campaigns/#{PLEDGIE_CAMPAIGN_ID}"
  end
end

