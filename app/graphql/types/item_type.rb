Types::ItemType = GraphQL::ObjectType.define do
  name "Item"
  description "A wearable Neopets item"

  field :id, !types.ID, "Unique identifier (matches Neopets.com ID)"
  field :name, !types.String, "Name of item (in English)"
  field :thumbnailUrl, !types.String, "URL for 80x80 item thumbnail",
    hash_key: :thumbnail_url

  # TODO: This has bad N+1 execution! How to fix in this paradigm?
  field :swfAssets, !types[!Types::SwfAssetType] do
    description "SWF assets for this item on the given body ID"
    argument :bodyId, !types.Int
    resolve ->(obj, args, ctx) {
      obj.swf_assets.fitting_body_id(args[:bodyId])
    }
  end
end