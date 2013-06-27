class Item
  class ProxyArray < Array
    METHOD_SCOPES = {as_json: Item.includes(:translations)}

    def initialize(ids)
      self.replace(ids.map { |id| Proxy.new(id.to_i) })
    end

    def prepare_method(method_name)
      missed_proxies_by_id = self.
        reject { |p| p.method_cached?(method_name) }.
        index_by(&:id)
      item_scope = METHOD_SCOPES[method_name.to_sym] || Item.scoped
      item_scope.find(missed_proxies_by_id.keys).each do |item|
        missed_proxies_by_id[item.id].item = item
      end
    end
  end
end