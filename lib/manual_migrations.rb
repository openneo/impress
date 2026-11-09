# Checks pending migrations for ones that are marked to be run by hand, instead
# of automatically during deploys. See docs/database-migrations.md.
#
# To mark a migration, add this comment to its file, usually near the top, and
# say why (optionally) on the same line:
#
#     # deploy: run manually (rebuilds the whole swf_assets table)
module ManualMigrations
  MARKER = /^\s*#\s*deploy:\s*run manually\b/i

  # `manual` lists pending migrations that are marked to be run by hand.
  #
  # `blocked` lists pending migrations that *aren't* marked, but can't run
  # automatically either, because marked ones are pending too. (Deploys skip
  # all migrations while a marked one is pending, because they need to run in
  # order. So an unmarked migration from a later change would never run, and
  # its code would ship without it.) It's empty when `manual` is.
  Result = Data.define(:manual, :blocked)

  # Checks the pending migrations across all of this environment's databases.
  #
  # NOTE: This uses the same (internal) Active Record helpers that Rails's own
  # `db:migrate:status` task uses, so a Rails upgrade could change them. If
  # that happens, `spec/lib/manual_migrations_spec.rb` should fail loudly.
  def self.check
    paths = []
    ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each do |pool|
      paths.concat pending_paths_in(pool.migration_context)
    end
    check_paths(paths)
  end

  def self.check_paths(pending_paths)
    manual, unmarked = pending_paths.partition { |path| marked?(path) }
    Result.new(manual:, blocked: manual.empty? ? [] : unmarked)
  end

  def self.pending_paths_in(migration_context)
    pending_versions = migration_context.pending_migration_versions
    migration_context.migrations.
      select { |migration| pending_versions.include?(migration.version) }.
      map(&:filename)
  end

  def self.marked?(path)
    File.foreach(path).any? { |line| MARKER.match?(line) }
  end
end
