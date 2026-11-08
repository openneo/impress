# `app/services`: external integrations only

In this app, `app/services` holds clients for **external** services and APIs:
Neopets (`neopets/`), NeoPass, the Neopets media archive, Discord, LeBron's NC
values, and so on.

It is *not* for "service objects" in the general sense. Domain logic that
spans several records, or doesn't fit neatly on one model, goes in
`app/models`, namespaced under the model it's most about. For example:

- `Pet::AutoModeling` (`app/models/pet/auto_modeling.rb`)
- `Item::Search` (`app/models/item/search.rb`)
- `AuthUser::Deletion` (`app/models/auth_user/deletion.rb`)

Rails itself has no official `app/services` convention. Many codebases use it
for service objects, but this one doesn't, so please check here before adding
to it!
