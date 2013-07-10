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

    def cached?(type, name)
      # TODO: is there a way to cache nil? Right now we treat is as a miss.
      # We eagerly read the cache rather than just check if the value exists,
      # which will usually cut down on cache requests.
      @known_outputs[type][name] ||= Rails.cache.read(fragment_key(type, name))
      !@known_outputs[type][name].nil?
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

    def fragment_key(type, name)
      prefix = type == :partial ? 'views/' : ''
      base = localize_fragment_key("items/#{@id}##{name}", I18n.locale)
      prefix + base
    end
  end
end