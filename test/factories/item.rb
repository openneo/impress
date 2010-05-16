Factory.define :item do |i|
  i.name 'Test Item'
  i.description 'Test Description'
  i.thumbnail_url 'http://images.neopets.com/foo.gif'
  i.zones_restrict ''
  i.category ''
  i.add_attribute :type, ''
  i.rarity 0
  i.rarity_index 0
  i.price 0
  i.weight_lbs 0
  i.species_support_ids ''
  i.sold_in_mall false
  i.last_spidered 0
end
