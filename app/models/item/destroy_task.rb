class Item
  class DestroyTask
    extend FragmentExpiration

    TIMEOUT_IN_SECONDS = 10

    @queue = :item_destroy

    def self.perform(id)
      Timeout::timeout(TIMEOUT_IN_SECONDS) do
        # TODO: it's kinda ugly to reach across classes like this
        CreateTask.expire_newest_items
      end
    end
  end
end