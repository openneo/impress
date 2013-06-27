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

    def initialize(ids)
      self.replace(ids.map { |id| Proxy.new(id.to_i) })
    end

    def prepare_method(name)
      prepare(:method, name)
    end

    def prepare_partial(name)
      prepare(:partial, name)
    end

    private

    def prepare(type, name)
      missed_proxies_by_id = self.
        reject { |p| p.cached?(type, name) }.
        index_by(&:id)
      item_scope = SCOPES[type][name]
      raise "unexpected #{type} #{name.inspect}" unless item_scope
      item_scope.find(missed_proxies_by_id.keys).each do |item|
        missed_proxies_by_id[item.id].item = item
      end
    end
  end
end