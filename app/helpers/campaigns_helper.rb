module CampaignsHelper
  def emote_md(text)
    text = text.
      gsub(/:\)/, image_tag('emoticons/smiley.gif')).
      gsub(/:D/, image_tag('emoticons/grin.gif')).
      gsub(/:P/, image_tag('emoticons/tongue.gif'))
    md text
  end
end
