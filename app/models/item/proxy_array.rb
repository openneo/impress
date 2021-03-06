class Item
  class ProxyArray < Array
    # TODO: do we really need to include translations? The search documents
    #       know the proper name for each locale, so proxies can tell their
    #       parent items what their names are and save the query entirely.
    SCOPES = HashWithIndifferentAccess.new({
      method: {
        as_json: Item.includes(:translations),
      },
      partial: {
        item_link_partial: Item.includes(:translations)
      }
    })

    def initialize(proxies_or_items_or_ids=[])
      self.replace(proxies_or_items_or_ids.map { |proxy_or_item_or_id|
        if proxy_or_item_or_id.is_a?(Proxy)
          proxy_or_item_or_id
        else
          Proxy.new(proxy_or_item_or_id)
        end
      })
    end

    def prepare_method(name)
      prepare(:method, name)
    end

    def prepare_partial(name)
      prepare(:partial, name)
    end

    private

    def prepare(type, name)
      item_scope = SCOPES[type][name]
      raise "unexpected #{type} #{name.inspect}" unless item_scope

      # Try to read all values from the cache in one go, setting the proxy
      # values as we go along. Delete successfully set proxies, so that
      # everything left in proxies_by_key in the end is known to be a miss.
      proxies_by_key = {}
      self.each do |p|
        proxies_by_key[p.fragment_key(type, name)] ||= []
        proxies_by_key[p.fragment_key(type, name)] << p
      end
      Rails.cache.read_multi(*proxies_by_key.keys).each { |k, v|
        proxies_by_key.delete(k).each { |p| p.set_known_output(type, name, v) }
      }

      missed_proxies = proxies_by_key.values.flatten
      missed_proxies_by_id = missed_proxies.index_by(&:id)

      item_scope.find(missed_proxies_by_id.keys).each do |item|
        missed_proxies_by_id[item.id].item = item
      end
    end
  end
end