require 'yaml'

class ClosetPage
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  @selectors = {
    :items          => "form[action=\"process_closet.phtml\"] tr[bgcolor!=silver][bgcolor!=\"#E4E4E4\"]",
    :item_thumbnail => "img",
    :item_name      => "td:nth-child(2)",
    :item_quantity  => "td:nth-child(5)",
    :item_remove    => "input",
    :page_select    => "select[name=page]",
    :selected       => "option[selected]"
  }

  attr_accessor :index
  attr_reader :hangers, :source, :total_pages, :unknown_item_names, :user

  def initialize(user)
    raise ArgumentError, "Expected #{user.inspect} to be a User", caller unless user.is_a?(User)
    @user = user
  end

  def last?
    @index == @total_pages
  end

  def name
    I18n.translate('neopets_pages.names.closet')
  end

  def persisted?
    false
  end

  def save_hangers!
    counts = {:created => 0, :updated => 0}
    ClosetHanger.transaction do
      @hangers.each do |hanger|
        if hanger.new_record?
          counts[:created] += 1
          hanger.save!
        elsif hanger.changed?
          counts[:updated] += 1
          hanger.save!
        end
      end
    end
    counts
  end

  def source=(source)
    @source = source
    parse_source!(source)
  end

  def url
    "http://www.neopets.com/closet.phtml?per_page=50&page=#{@index}"
  end

  protected

  def element(selector_name, parent)
    parent.at_css(self.class.selectors[selector_name]) ||
      raise(ParseError, "#{selector_name} element not found")
  end

  def elements(selector_name, parent)
    parent.css(self.class.selectors[selector_name])
  end

  def find_id(row)
    element(:item_remove, row)['name']
  end

  def find_index(page_selector)
    element(:selected, page_selector)['value'].to_i
  end

  def find_items(doc)
    elements(:items, doc)
  end

  def find_name(row)
    # For normal items, the td contains essentially:
    # <b>NAME<br/><span>OPTIONAL ADJECTIVE</span></b>
    # For PB items, the td contains:
    # NAME<br/><span>OPTIONAL ADJECTIVE</span>
    # So, we want the first text node. If it's a PB item, that's the first
    # child. If it's a normal item, it's the first child <b>'s child.
    name_el = element(:item_name, row).children[0]
    name_el = name_el.children[0] if name_el.name == 'b'
    name_el.text
  end

  def find_page_selector(doc)
    element(:page_select, doc)
  end

  def find_quantity(row)
    element(:item_quantity, row).text.to_i
  end

  def find_thumbnail_url(row)
    element(:item_thumbnail, row)['src']
  end

  def find_total_pages(page_selector)
    page_selector.children.size
  end

  def parse_source!(source)
    doc = Nokogiri::HTML(source)

    page_selector = find_page_selector(doc)
    @total_pages = find_total_pages(page_selector)
    @index = find_index(page_selector)

    items_data = {
      :id => {},
      :thumbnail_url => {}
    }


    # Go through the items, and find the ID/thumbnail for each and data with it
    find_items(doc).each do |row|
      data = {
        :name => find_name(row),
        :quantity => find_quantity(row)
      }

      if id = find_id(row)
        id = id.to_i
        items_data[:id][id] = data
      else # if this is a pb item, which does not give ID, go by thumbnail
        thumbnail_url = find_thumbnail_url(row)
        items_data[:thumbnail_url][thumbnail_url] = data
      end
    end

    # Find items with either a matching ID or matching thumbnail URL
    # Check out that single-query beauty :)
    i = Item.arel_table
    items = Item.where(
      i[:id].in(items_data[:id].keys).
      or(
        i[:thumbnail_url].in(items_data[:thumbnail_url].keys)
      )
    )

    # Create closet hanger from each item, and remove them from the reference
    # lists
    @hangers = items.map do |item|
      data = items_data[:id].delete(item.id) ||
        items_data[:thumbnail_url].delete(item.thumbnail_url)
      hanger = @user.closet_hangers.find_or_initialize_by_item_id(item.id)
      hanger.quantity = data[:quantity]
      hanger
    end

    # Take the names of the items remaining in the reference lists, meaning
    # that they weren't found
    @unknown_item_names = []
    items_data.each do |type, data_by_key|
      data_by_key.each do |key, data|
        @unknown_item_names << data[:name]
      end
    end
  end

  def self.selectors
    @selectors
  end

  class ParseError < RuntimeError;end
end

