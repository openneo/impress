namespace :deploy do
  # `deploy/deploy.yml` runs this before migrating, and decides what to do
  # from its output. See docs/database-migrations.md.
  #
  # - "MANUAL MIGRATION:" lines are pending migrations marked to be run by
  #   hand. The deploy skips migrations, ships the code, and fails at the end,
  #   so someone notices.
  # - "BLOCKED MIGRATION:" lines are unmarked pending migrations that can't
  #   run while marked ones are pending. The deploy stops before switching to
  #   the new code, which might depend on them.
  #
  # Each line has a prefix because in production, Rails also logs to stdout,
  # and the deploy needs to tell our output apart from logs.
  desc "List pending migrations that block an automatic deploy"
  task check_migrations: :environment do
    result = ManualMigrations.check
    result.manual.each { |path| puts "MANUAL MIGRATION: #{path}" }
    result.blocked.each { |path| puts "BLOCKED MIGRATION: #{path}" }
  end
end
