require 'open-uri'

class NeopetsUser
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :username
  attr_reader :hangers

  def initialize(app_user)
    @app_user = app_user
  end

  def load!
    doc = Nokogiri::HTML(open(url))

    unless pets_wrapper = doc.at('#userneopets')
      raise NotFound, "Could not find user #{username}"
    end

    pets = pets_wrapper.css('a[href^="/petlookup.phtml"]').map do |link|
      name = link['href'].split('=').last
      Pet.find_or_initialize_by_name(name)
    end

    items = pets.each(&:load!).map(&:items).flatten
    item_ids = items.map(&:id)

    existing_hanger_item_ids = @app_user.closet_hangers.select(:item_id).where(:item_id => item_ids).map(&:item_id)

    @hangers = []
    items.each do |item|
      next if existing_hanger_item_ids.include?(item.id)
      hanger = @app_user.closet_hangers.build
      hanger.item = item
      hanger.quantity = 1
      @hangers << hanger
    end
  end

  def save_hangers!
    ClosetHanger.transaction { @hangers.each(&:save!) }
  end

  def persisted?
    false
  end

  protected

  URL_PREFIX = 'http://www.neopets.com/userlookup.phtml?user='
  def url
    URL_PREFIX + @username
  end

  class NotFound < RuntimeError;end
end

