require 'rocketamf/remote_gateway'
require 'open-uri'

class NeopetsUser
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  NEOPETS_URL_ORIGIN = ENV['NEOPETS_URL_ORIGIN'] || 'http://www.neopets.com'
  GATEWAY_URL = NEOPETS_URL_ORIGIN + '/amfphp/gateway.php'
  GET_PETS_METHOD = RocketAMF::RemoteGateway.new(GATEWAY_URL).
    service('MobileService').action('getPets')

  attr_accessor :username
  attr_reader :hangers, :list_id

  def initialize(app_user)
    @app_user = app_user
  end

  def list_id=(list_id)
    # TODO: use null lists instead
    @list_id = list_id
    if list_id == 'true'
      @closet_list = nil
      @hangers_owned = true
    elsif list_id == 'false'
      @closet_list = nil
      @hangers_owned = false
    elsif list_id.present?
      @closet_list = @app_user.closet_lists.find(list_id)
      @hangers_owned = @closet_list.hangers_owned?
    end
  end

  def load!
    neopets_language_code = I18n.compatible_neopets_language_code_for(I18n.locale)
    begin
      envelope = GET_PETS_METHOD.request([@username]).post(
        :timeout => 4,
        :headers => {
          'Cookie' => "lang=#{neopets_language_code}"
        }
      )
    rescue RocketAMF::RemoteGateway::AMFError => e
      raise NotFound, e.message
    rescue RocketAMF::RemoteGateway::ConnectionError => e
      raise NotFound, e.message, e.backtrace
    end


    pets_data = envelope.messages[0].data.body
    raise NotFound if pets_data == false
    pets = pets_data.map { |pet| Pet.find_or_initialize_by(name: pet['name']) }
    items = pets.each(&:load!).map(&:items).flatten
    item_ids = items.map(&:id)
    item_quantities = {}
    items.each do |i|
      item_quantities[i] ||= 0
      item_quantities[i] += 1
    end

    # TODO: DRY up with NeopetsPage
    # We don't want to insert duplicate hangers of what a user owns if they
    # already have it in another list (e.g. imports to Items You Own *after*
    # curating their Up For Trade list), so we check for the hanger's presence
    # in *all* items the user owns or wants (whichever is appropriate for this
    # request).
    hangers_scope = @app_user.closet_hangers.where(owned: @hangers_owned)
    existing_hanger_item_ids = hangers_scope.select(:item_id).
      where(item_id: item_ids).map(&:item_id)

    @hangers = []
    item_quantities.each do |item, quantity|
      next if existing_hanger_item_ids.include?(item.id)
      hanger = hangers_scope.build
      hanger.item = item
      hanger.quantity = quantity
      hanger.list = @closet_list
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

