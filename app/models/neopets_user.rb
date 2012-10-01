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
    user = Neopets::User.new(@username)
    
    begin
      pets = user.pets
    rescue Neopets::User::Error => e
      raise NotFound, e.message
    end

    pets = pets.map { |pet| Pet.find_or_initialize_by_name(pet.name) }
    items = pets.each(&:load!).map(&:items).flatten
    item_ids = items.map(&:id)
    existing_hanger_item_ids = @app_user.closet_hangers.select(:item_id).where(:item_id => item_ids).map(&:item_id)
    item_quantities = {}
    items.each do |i|
      item_quantities[i] ||= 0
      item_quantities[i] += 1
    end

    @hangers = []
    item_quantities.each do |item, quantity|
      next if existing_hanger_item_ids.include?(item.id)
      hanger = @app_user.closet_hangers.build
      hanger.item = item
      hanger.quantity = quantity
      @hangers << hanger
    end
  end

  def save_hangers!
    ClosetHanger.transaction { @hangers.each(&:save!) }
  end

  def persisted?
    false
  end
  
  class NotFound < RuntimeError; end
end

