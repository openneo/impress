Types::ZoneType = GraphQL::ObjectType.define do
  name "Zone"
  description "A zone that an SWFAsset occupies"

  field :label, !types.String, "Human-readable zone name"
  field :depth, !types.Int,
    "Where this zone sits in layer hierarchy. (Lower on bottom, higher on top)"
end