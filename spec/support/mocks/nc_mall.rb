# We replace Neopets::NCMall.fetch_pet_data_sci with a mocked implementation.
module Neopets::NCMall
  # Mock implementation that generates predictable SCI hashes for testing.
  # The hash is derived from the pet_sci and item_ids to ensure consistency.
  def self.fetch_pet_data_sci(pet_sci, item_ids = [])
    "#{pet_sci}-#{item_ids.sort.join('-')}"
  end
end
