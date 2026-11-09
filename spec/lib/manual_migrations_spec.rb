require_relative '../rails_helper'

RSpec.describe ManualMigrations do
  describe ".marked?" do
    def marked?(content)
      Tempfile.create(["migration", ".rb"]) do |file|
        file.write(content)
        file.flush
        ManualMigrations.marked?(file.path)
      end
    end

    it "finds the marker comment" do
      expect(marked?("# deploy: run manually\nclass Foo; end\n")).to be true
    end

    it "allows an explanation after the marker" do
      expect(marked?("# deploy: run manually (rebuilds swf_assets)\n")).
        to be true
    end

    it "ignores case and extra spaces" do
      expect(marked?("  #   Deploy:  Run Manually\n")).to be true
    end

    it "ignores migrations without the marker" do
      expect(marked?("class Foo < ActiveRecord::Migration[8.1]; end\n")).
        to be false
    end

    it "ignores the marker when it's not a whole comment" do
      expect(marked?("# Don't add `# deploy: run manually` here\n")).to be false
    end
  end

  describe "with migration files" do
    around do |example|
      Dir.mktmpdir { |dir| @dir = dir; example.run }
    end

    def write_migration(version, name, marked: false)
      path = File.join(@dir, "#{version}_#{name}.rb")
      File.write(path, marked ? "# deploy: run manually\n" : "")
      path
    end

    describe ".pending_paths_in" do
      def migration_context
        pool = ActiveRecord::Base.connection_pool
        ActiveRecord::MigrationContext.new(@dir, pool.schema_migration,
          pool.internal_metadata)
      end

      # (Rails rejects migration timestamps from the future, so our "pending"
      # migrations use old timestamps that were never applied.)
      it "returns the migrations that haven't been applied" do
        applied_version = ActiveRecord::Base.connection_pool.
          migration_context.get_all_versions.max
        write_migration(applied_version, "already_applied")
        pending = write_migration(20000101000001, "pending")

        expect(ManualMigrations.pending_paths_in(migration_context)).
          to eq([pending])
      end
    end

    describe ".check_paths" do
      it "is all clear when nothing is marked" do
        unmarked = write_migration(20000101000001, "unmarked")

        result = ManualMigrations.check_paths([unmarked])
        expect(result.manual).to eq([])
        expect(result.blocked).to eq([])
      end

      it "lists marked migrations as manual" do
        marked = write_migration(20000101000001, "marked", marked: true)

        result = ManualMigrations.check_paths([marked])
        expect(result.manual).to eq([marked])
        expect(result.blocked).to eq([])
      end

      it "blocks unmarked migrations while marked ones are pending" do
        marked = write_migration(20000101000001, "marked", marked: true)
        unmarked = write_migration(20000101000002, "unmarked")

        result = ManualMigrations.check_paths([marked, unmarked])
        expect(result.manual).to eq([marked])
        expect(result.blocked).to eq([unmarked])
      end
    end
  end

  describe ".check" do
    # This checks that the Active Record internals we use still work, across
    # both of our databases. The test databases have every migration applied,
    # so nothing should be pending.
    it "checks every database without errors" do
      result = ManualMigrations.check
      expect(result.manual).to eq([])
      expect(result.blocked).to eq([])
    end
  end
end
