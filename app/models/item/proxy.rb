class Item
  class Proxy
    include FragmentLocalization

    attr_reader :id
    attr_writer :item

    def initialize(id)
      @id = id
      @known_method_outputs = {}
    end

    def method_cached?(method_name)
      # TODO: is there a way to cache nil? Right now we treat is as a miss.
      # We eagerly read the cache rather than just check if the value exists,
      # which will usually cut down on cache requests.
      @known_method_outputs[method_name] ||= Rails.cache.read(
        method_fragment_key(method_name))
      !@known_method_outputs[method_name].nil?
    end

    def as_json(options={})
      cache_method(:as_json)
    end

    private

    def cache_method(method_name, &block)
      # Two layers of cache: a local copy, in case the method is called again,
      # and then the Rails cache, before we hit the actual method call.
      @known_method_outputs[method_name] ||= begin
        key = method_fragment_key(method_name)
        Rails.cache.fetch(key) { item.send(method_name) }
      end
    end

    def item
      @item ||= Item.find(@id)
    end

    def method_fragment_key(method_name)
      localize_fragment_key("item/#{@id}##{method_name}", I18n.locale)
    end
  end
end