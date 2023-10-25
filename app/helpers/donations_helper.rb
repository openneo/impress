module DonationsHelper
  THANK_YOU_GREETINGS = [
    'https://images.neopets.com/new_greetings/1368.gif',
    'https://images.neopets.com/new_greetings/466.gif',
    'https://images.neopets.com/new_greetings/48.gif',
    'https://images.neopets.com/new_greetings/49.gif',
    'https://images.neopets.com/new_greetings/64.gif',
    'https://images.neopets.com/new_greetings/65.gif',
    'https://images.neopets.com/new_greetings/66.gif',
    'https://images.neopets.com/new_greetings/67.gif',
    'https://images.neopets.com/new_greetings/69.gif',
    'https://images.neopets.com/new_greetings/71.gif',
    'https://images.neopets.com/new_greetings/72.gif',
    'https://images.neopets.com/new_greetings/103.gif',
    'https://images.neopets.com/new_greetings/420.gif'
  ]

  def thank_you_greeting_url
    THANK_YOU_GREETINGS.sample
  end

  def feature_outfit_url(outfit_id)
    outfit_url(outfit_id) if outfit_id
  end
end
