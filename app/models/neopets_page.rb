class NeopetsPage
  include ActiveModel::Conversion
  extend ActiveModel::Naming


  delegate :name, to: :type


  attr_reader :type, :expected_index, :source


  def initialize(type_key, expected_index, source)
    begin
      @type = TYPES.fetch(type_key)
    rescue KeyError
      raise TypeNotFound, type_key
    end
    @expected_index = expected_index
    @source = source
  end


  def build_import_task(user, list_id)
    ImportTask.new self, user, list_id
  end


  def url
    @type.url(@expected_index)
  end


  def index
    parse_results[:index]
  end


  def page_count
    parse_results[:page_count]
  end


  def last?
    Rails.logger.debug("last? #{index} == #{page_count}")
    index == page_count
  end


  def parse_results
    @parse_results ||= @type.parse @source
  end


  def item_refs
    parse_results[:items]
  end


  def persisted?
    false
  end


  def to_param
    @expected_index
  end



  class ItemRef
    attr_reader :id, :thumbnail_url, :name, :quantity

    def initialize(id, thumbnail_url, name, quantity)
      @id = id
      @thumbnail_url = thumbnail_url
      @name = name
      @quantity = quantity
    end

    def id?
      @id.present?
    end
  end



  class Parser
    def initialize(params)
      @selectors = params.fetch(:selectors)
      @parse_id = params.fetch(:parse_id, lambda { |id| id })
      @parse_index = params.fetch(:parse_index, lambda { |index| index })
      @has_quantity = params.fetch(:has_quantity, true)
      @has_id = params.fetch(:has_id, true)
      @has_pages = params.fetch(:has_pages, true)
    end


    def parse(source)
      doc = Nokogiri::HTML(source)
      page_selector = find_page_selector(doc)
      {items: find_items(doc), index: find_index(page_selector), page_count: find_page_count(page_selector)}
    end


    def element(selector_name, parent)
      selector = @selectors[selector_name]
      parent.at_css(selector) ||
        raise(ParseError, "#{selector_name} element not found (#{selector} in #{parent})")
    end


    def elements(selector_name, parent)
      parent.css(@selectors[selector_name])
    end


    def find_id(row)
      @parse_id.call(element(:item_remove, row)['name']).try(:to_i) if @has_id
    end


    def find_index(page_selector)
      if @has_pages
        @parse_index.call(element(:selected, page_selector)['value'].to_i)
      else
        1
      end
    end


    def find_items(doc)
      elements(:items, doc).map do |el|
        ItemRef.new(find_id(el), find_thumbnail_url(el), find_name(el), find_quantity(el))
      end
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
      element(:page_select, doc) if @has_pages
    end


    def find_quantity(row)
      if @has_quantity
        element(:item_quantity, row).text.to_i
      else
        1
      end
    end


    def find_thumbnail_url(row)
      element(:item_thumbnail, row)['src']
    end


    def find_page_count(page_selector)
      if @has_pages
        page_selector.css('option').size
      else
        1
      end
    end
  end



  class Type
    attr_reader :parser
    delegate :parse, to: :parser


    def initialize(params)
      @get_name = params.fetch(:get_name)
      @get_url = params.fetch(:get_url)
      @parser = params.fetch(:parser)
    end


    def name
      @get_name.call
    end


    def url(index)
      @get_url.call(index)
    end
  end



  TYPES = {
    'closet' => Type.new(
      get_name: lambda { I18n.translate('neopets_page_import_tasks.names.closet') },
      get_url: lambda { |index| "https://www.neopets.com/closet.phtml?per_page=50&page=#{index}" },
      parser: Parser.new(
        selectors: {
          items:          "form[action=\"process_closet.phtml\"] tr[bgcolor!=silver][bgcolor!=\"#E4E4E4\"]",
          item_thumbnail: "img",
          item_name:      "td:nth-child(2)",
          item_quantity:  "td:nth-child(5)",
          item_remove:    "input",
          page_select:    "select[name=page]",
          selected:       "option[selected]"
        }
      )
    ),
    'safety_deposit' => Type.new(
      get_name: lambda { I18n.translate('neopets_page_import_tasks.names.safety_deposit') },
      get_url: lambda { |index| "https://www.neopets.com/safetydeposit.phtml?offset=#{(index - 1) * 30}" },
      parser: Parser.new(
        selectors: {
          items:          "#content tr[bgcolor=\"#DFEAF7\"]",
          item_thumbnail: "img",
          item_name:      "td:nth-child(2)",
          item_quantity:  "td:nth-child(5)",
          item_remove:    "input",
          page_select:    "select[name=offset]",
          selected:       "option[selected]"
        },
        parse_id: lambda { |id|
          unless match = id.match(/\[([0-9]+)\]/)
            raise ParseError, "Remove Item input name format was unexpected: #{id}.inspect"
          end
          match[1]
        },
        parse_index: lambda { |offset| offset / 30 + 1 }
      )
    ),
    'gallery' => Type.new(
      get_name: lambda { I18n.translate('neopets_page_import_tasks.names.gallery') },
      get_url: lambda { |index| "https://www.neopets.com/gallery/index.phtml?view=all" },
      parser: Parser.new(
        selectors: {
          items:          "form[name=gallery_form] td[valign=top]",
          item_thumbnail: "img",
          item_name:      "b"
        },
        has_quantity: false,
        has_id: false,
        has_pages: false
      )
    )
  }



  class ImportTask
    include ActiveModel::Conversion
    extend ActiveModel::Naming


    attr_reader :page, :list_id


    def initialize(page, user, list_id)
      @page = page
      @user = user
      @list_id = list_id
    end


    def save
      item_refs = @page.item_refs

      item_refs_by_best_key = {id: {}, thumbnail_url: {}}
      item_refs.each do |item_ref|
        if item_ref.id?
          item_refs_by_best_key[:id][item_ref.id] = item_ref
        else
          item_refs_by_best_key[:thumbnail_url][item_ref.thumbnail_url] = item_ref
        end
      end

      # Find items with either a matching ID or matching thumbnail URL
      # Check out that single-query beauty :)
      i = Item.arel_table
      items = Item.where(
        i[:id].in(item_refs_by_best_key[:id].keys).
        or i[:thumbnail_url].in(item_refs_by_best_key[:thumbnail_url].keys)
      )

      # And now for some more single-query beauty: check for existing hangers.
      # We don't want to insert duplicate hangers of what a user owns if they
      # already have it in another list (e.g. imports to Items You Own *after*
      # curating their Up For Trade list), so we check for the hanger's presence
      # in *all* items the user owns or wants (whichever is appropriate for this
      # request).
      hangers_scope = @user.closet_hangers.where(owned: list.hangers_owned?)

      # Group existing hangers by item ID and whether they're from the current
      # list or another list.
      current_list_id = list.try_non_null(:id)
      existing_hangers_by_item_id = hangers_scope.
        where(item_id: items.map(&:id)).
        group_by(&:item_id)

      # Careful! We're just using a single default empty list for performance,
      # but it must not be mutated! If mutation becomes necessary, change this
      # to a default_proc assignment.
      existing_hangers_by_item_id.default = []

      # Create closet hanger from each item, and remove them from the reference
      # lists.
      hangers = items.map do |item|
        data = item_refs_by_best_key[:id].delete(item.id) ||
          item_refs_by_best_key[:thumbnail_url].delete(item.thumbnail_url)

        # If there's a hanger in the current list, we want it so we can update
        # its quantity. If there's a hanger in another list, we want it so we
        # know not to build a new one. Otherwise, build away!
        existing_hangers = existing_hangers_by_item_id[item.id]
        existing_hanger_in_current_list = existing_hangers.detect { |h|
          h.list_id == current_list_id
        }
        hanger = existing_hanger_in_current_list || existing_hangers.first ||
                 hangers_scope.build

        # We also don't want to move existing hangers from other lists, so only
        # set the list if the hanger is new. (The item assignment is only
        # necessary for new records, so may as well put it here, too.)
        if hanger.new_record?
          hanger.item = item
          hanger.list_id = current_list_id
        end

        # Finally, we don't want to update the quantity of hangers in those other
        # lists, either, so only update quantity if it's in this list. (This will
        # be true for some existing hangers and all new hangers. This is also the
        # only value that could change for existing hangers; if nothing changes,
        # it was an existing hanger from another list.)
        hanger.quantity = data.quantity if hanger.list_id == current_list_id

        hanger
      end

      # Take the names of the items remaining in the reference lists, meaning
      # that they weren't found
      unknown_item_names = []
      item_refs_by_best_key.each do |type, item_refs_by_key|
        item_refs_by_key.each do |key, item_ref|
          unknown_item_names << item_ref.name
        end
      end

      counts = {created: 0, updated: 0, unchanged: 0}
      ClosetHanger.transaction do
        hangers.each do |hanger|
          if hanger.new_record?
            counts[:created] += 1
            Rails.logger.debug("hanger: #{hanger.inspect}")
            hanger.save!
          elsif hanger.changed?
            counts[:updated] += 1
            hanger.save!
          else
            counts[:unchanged] += 1
          end
        end
      end

      {counts: counts, unknown_item_names: unknown_item_names}
    end


    def list
      @list ||= @user.find_closet_list_by_id_or_null_owned list_id
    end


    def persisted?
      false
    end
  end


  class ParseError < RuntimeError; end
  class TypeNotFound < RuntimeError; end
end
