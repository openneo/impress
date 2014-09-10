module DonationsHelper
  THANK_YOU_GREETINGS = [
    'http://images.neopets.com/new_greetings/1368.gif',
    'http://images.neopets.com/new_greetings/466.gif',
    'http://images.neopets.com/new_greetings/48.gif',
    'http://images.neopets.com/new_greetings/49.gif',
    'http://images.neopets.com/new_greetings/64.gif',
    'http://images.neopets.com/new_greetings/65.gif',
    'http://images.neopets.com/new_greetings/66.gif',
    'http://images.neopets.com/new_greetings/67.gif',
    'http://images.neopets.com/new_greetings/69.gif',
    'http://images.neopets.com/new_greetings/71.gif',
    'http://images.neopets.com/new_greetings/72.gif',
    'http://images.neopets.com/new_greetings/103.gif',
    'http://images.neopets.com/new_greetings/420.gif'
  ]

  def thank_you_greeting_url
    THANK_YOU_GREETINGS.sample
  end

  def feature_outfit_url(outfit_id)
    outfit_url(outfit_id) if outfit_id
  end
end
