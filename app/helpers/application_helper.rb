module ApplicationHelper
  def flashes
    flash.inject('') do |html, pair|
      key, value = pair
      content_tag 'p', value, :class => key
    end
  end
end
