require 'yaml'

class ClosetPage
  SELECTORS = {
    :items          => "form[action=\"process_closet.phtml\"] tr[bgcolor!=silver][bgcolor!=\"#E4E4E4\"]",
    :item_thumbnail => "img",
    :item_name      => "td:nth-child(2)",
    :item_quantity  => "td:nth-child(5)",
    :item_remove    => "input",
    :page_select    => "select[name=page]",
    :selected       => "option[selected]"
  }

  attr_reader :hangers, :index, :total_pages, :unknown_item_names

  def initialize(user)
    raise ArgumentError, "Expected #{user.inspect} to be a User", caller unless user.is_a?(User)
    @user = user
  end

  def save_hangers!
    @hangers.each(&:save!)
  end

  def source=(source)
    parse_source!(source)
  end

  protected

  def element(selector_name, parent)
    parent.at_css(SELECTORS[selector_name]) ||
      raise(ParseError, "Closet #{selector_name} element not found in #{parent.inspect}")
  end

  def elements(selector_name, parent)
    parent.css(SELECTORS[selector_name])
  end

  def parse_source!(source)
    doc = Nokogiri::HTML(source)

    page_selector = element(:page_select, doc)
    @total_pages = page_selector.children.size
    @index = element(:selected, page_selector)['value']

    items_data = {
      :id => {},
      :thumbnail_url => {}
    }

    # Go through the items, and find the ID/thumbnail for each and data with it
    elements(:items, doc).each do |row|
      # For normal items, the td contains essentially:
      # <b>NAME<br/><span>OPTIONAL ADJECTIVE</span></b>
      # For PB items, the td contains:
      # NAME<br/><span>OPTIONAL ADJECTIVE</span>
      # So, we want the first text node. If it's a PB item, that's the first
      # child. If it's a normal item, it's the first child <b>'s child.
      name_el = element(:item_name, row).children[0]
      name_el = name_el.children[0] if name_el.name == 'b'

      data = {
        :name => name_el.text,
        :quantity => element(:item_quantity, row).text.to_i
      }

      if id = element(:item_remove, row)['name']
        id = id.to_i
        items_data[:id][id] = data
      else # if this is a pb item, which does not give ID, go by thumbnail
        thumbnail_url = element(:item_thumbnail, row)['src']
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
      hanger = @user.closet_hangers.build
      hanger.item = item
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

  class ParseError < RuntimeError;end
end

