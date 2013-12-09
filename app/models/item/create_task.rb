class Item
  class CreateTask
    extend FragmentExpiration

    TIMEOUT_IN_SECONDS = 10

    @queue = :item_create

    def self.perform(id)
      Timeout::timeout(TIMEOUT_IN_SECONDS) do
        Item.find(id).flex.sync
        expire_newest_items
      end
    end

    def self.expire_newest_items
      expire_fragment_in_all_locales('outfits#new newest_items')
      expire_fragment_in_all_locales('items#index newest_items')
    end
  end
end