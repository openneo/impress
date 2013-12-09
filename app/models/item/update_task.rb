class Item
  class UpdateTask
    extend FragmentExpiration

    TIMEOUT_IN_SECONDS = 10

    @queue = :item_update

    def self.perform(id)
      Timeout::timeout(TIMEOUT_IN_SECONDS) do
        item = Item.find(id)
        expire_cache_for(item)
        item.flex.sync
      end
    end
    
    private

    def self.expire_cache_for(item)
      expire_fragment_in_all_locales("items/#{item.id}#item_link_partial")
      expire_fragment_in_all_locales("items/#{item.id} header")
      expire_fragment_in_all_locales("items/#{item.id} info")
      expire_key_in_all_locales("items/#{item.id}#as_json")
    end
  end
end