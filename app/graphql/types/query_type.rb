Types::QueryType = GraphQL::ObjectType.define do
  name "Query"
  # Add root-level fields here.
  # They will be entry points for queries on your schema.

  field :items, !types[!Types::ItemType] do
    argument :ids, !types[!types.ID]
    description "Find items by ID"
    resolve ->(obj, args, ctx) {
      Item.where(id: args[:ids])
    }
  end
end
