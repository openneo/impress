Types::SwfAssetType = GraphQL::ObjectType.define do
  name "SwfAsset"
  description "An SWF for a single layer of an item's appearance on a body"

  field :id, !types.ID, "Unique identifier (DTI-internal)"
  field :zone, !Types::ZoneType, "Zone that this asset occupies"

  field :largeImageUrl, !types.String do
    description "URL for 600x600 PNG image"
    resolve ->(obj, args, ctx) { obj.image_url(SwfAsset::IMAGE_SIZES[:large]) }
  end

end