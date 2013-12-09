class Item
  class Proxy
    include FragmentLocalization

    attr_reader :id
    attr_writer :item, :owned, :wanted

    delegate :description, :name, :nc?, :thumbnail_url, :to_param, to: :item

    def self.model_name
      Item.model_name
    end

    def initialize(id)
      @id = id
      @known_outputs = {method: {}, partial: {}}
    end

    def as_json(options={})
      cache_method(:as_json, include_hanger_status: false).tap do |json|
        json[:owned] = owned?
        json[:wanted] = wanted?
      end
    end

    def owned?
      @owned
    end

    def to_partial_path
      # HACK: could break without warning!
      Item._to_partial_path
    end

    def wanted?
      @wanted
    end

    def fragment_key(type, name)
      prefix = type == :partial ? 'views/' : ''
      base = localize_fragment_key("items/#{@id}##{name}", I18n.locale)
      prefix + base
    end

    def set_known_output(type, name, value)
      @known_outputs[type][name] = value
    end

    private

    def cache_method(method_name, *args, &block)
      # Two layers of cache: a local copy, in case the method is called again,
      # and then the Rails cache, before we hit the actual method call.
      @known_outputs[method_name] ||= begin
        key = fragment_key(:method, method_name)
        Rails.cache.fetch(key) { item.send(method_name, *args) }
      end
    end

    def item
      @item ||= Item.find(@id)
    end
  end
end