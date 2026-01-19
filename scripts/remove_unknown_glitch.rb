# Run with: rails runner scripts/remove_unknown_glitch.rb

ASSET_IDS = [
  39694,
  468669,
  497773,
  558774,
  139542,
  112686,
  225267,
  225277,
  225805,
  520525,
  537342,
  27886,
  94213,
  390340,
]

GLITCH_TO_REMOVE = "DISPLAYS_INCORRECTLY_BUT_CAUSE_UNKNOWN"

ASSET_IDS.each do |asset_id|
  asset = SwfAsset.find_by(id: asset_id)

  if asset.nil?
    puts "Asset #{asset_id}: NOT FOUND"
    next
  end

  before_glitches = asset.known_glitches

  unless before_glitches.include?(GLITCH_TO_REMOVE)
    puts "Asset #{asset_id}: Does not have #{GLITCH_TO_REMOVE}"
    next
  end

  after_glitches = before_glitches - [GLITCH_TO_REMOVE]
  asset.known_glitches = after_glitches
  asset.save!

  # Get the item via the relationship
  item_rel = asset.parent_swf_asset_relationships.find_by(parent_type: "Item")
  item = item_rel&.parent

  item_name = item&.name || "(no item)"
  item_id = item&.id || "(no item)"

  url = "http://impress.openneo.net/swf-assets/#{asset_id}?playing=true"

  puts "#{before_glitches.inspect} -> #{after_glitches.inspect} | #{item_name} | Item #{item_id} | Asset #{asset_id} | #{url}"
end

puts "\nDone!"
