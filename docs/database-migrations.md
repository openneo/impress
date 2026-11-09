# Database Migrations

Deploys run database migrations automatically. When a change lands in `main`,
CI deploys it (see [deployment-setup.md](./deployment-setup.md)), and the
deploy runs any pending migrations **before** switching production to the new
code.

That ordering means the new code never runs against an old schema. But it also
means the **old** code runs against the **new** schema for a bit, and so does
[Impress 2020](./impress-2020-dependencies.md), which reads and writes our
databases directly. So every migration needs to follow a few rules.

## The rules

1. **Compatible with the code that's already running.** That includes this
   app's previous version, and Impress 2020. Renaming or removing a column
   takes two deploys: first stop using it (`self.ignored_columns` helps), and
   check that Impress 2020 doesn't use it either. Then remove it in a later
   change.
2. **Fast.** A deploy waits for its migrations, and big tables lock while they
   change. Prefer changes MariaDB can make in place (adding columns and indexes
   usually can), and keep data backfills out of migrations: put them in a rake
   task, and run it by hand. The deploy job also has a 30-minute time limit,
   and stops wherever it is when time runs out. So if a migration might take
   more than a few minutes, mark it to run by hand (below).
3. **Safe to re-run.** MariaDB can't roll back schema changes, so if a
   migration fails partway, its earlier steps stay done. Write migrations so
   running them again picks up where they left off, e.g. with
   `if_not_exists: true` and `if_exists: true`.
4. **Quick to give up on locks.** A schema change that waits for a lock (say,
   behind a long-running query) makes every later query on that table wait
   behind *it*, which can stall the whole site. Set a short
   `lock_wait_timeout`, so it fails fast instead, and can be re-run.

`db/migrate/20261108120000_add_user_lookup_indexes.rb` is a good example of
rules 2–4.

## Migrations that need a person

Sometimes a migration can't follow these rules, e.g. it rebuilds a huge table,
or needs a quiet moment. To keep a deploy from running it, mark the migration
file with this comment, and say why if you like:

```ruby
# deploy: run manually (rebuilds the whole swf_assets table)
class RebuildSwfAssets < ActiveRecord::Migration[8.1]
```

When a pending migration is marked, the deploy skips running migrations
altogether (they need to run in order), and ships the code anyway. So **the code
in that change has to work whether or not the migration has run yet**. Then the
deploy **fails at the very end**, so the run shows up red, and its log lists the
migrations that still need running.

When you're ready, run them on the server:

```sh
ssh impress.openneo.net
sudo -iu impress
cd /srv/impress/current && bin/rails db:migrate
```

**Until you do, deploys with new migrations stop before switching versions.**
While a marked migration is pending, any *unmarked* pending migration (say, from
a later change) can't run either, but its code might depend on it. So the
deploy stops before switching to the new code, leaves the current version
running, and lists what's blocked. Run the marked migrations, then re-run the
deploy. (Changes without migrations still deploy in the meantime, though each
run ends red with the same reminder.)

If one change adds both kinds, mark them all: they'll all wait for a person
anyway.

You can also skip migrations for a single manual deploy, with
`bin/deploy -e skip_migrations=yes`.

## Rollbacks don't undo migrations

`bin/deploy:rollback` switches back to the previous version of the code, but
leaves the database as it is. That's another reason for rule 1: the previous
version should still work with the new schema.
