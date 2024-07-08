require "open-uri"
require "open3"

desc "Tools to save and import DTI's public modeling data"
namespace :public_data do
	desc "Save the local database's public data to a local file"
	task :commit, [:name] => :environment do |_, args|
		if Rails.env.development?
			puts "NOTE: The `public_data:commit` task is primarily meant to be " +
				"run in production, to create public data files we can copy to our " +
				"development machines via `public_data:pull`. I'll still run it " +
				"locally and save to #{Rails.configuration.public_data_root}, though!"
		end

		# Generate a filename from the current time, and the option name argument
		# provided to the command (e.g. `rails public_data:commit[scheduled]`).
		timestamp = Time.now.utc.iso8601.gsub(':', '_')
		name = args.fetch(:name, "manual")
		filename = "#{timestamp}-#{name}.sql.gz"
		dest_path = Rails.configuration.public_data_root / filename

		args = []

		# The connection details for our database!
		config = ApplicationRecord.connection_db_config.configuration_hash
		args << "--host=#{config[:host]}" if config[:host]
		args << "--user=#{config[:username]}" if config[:username]
		args << "--password=#{config[:password]}" if config[:password]

		# Don't lock the database to do it!
		args << "--single-transaction"

		# Skip dumping tablespaces, so this requires fewer privileges.
		args << "--no-tablespaces"

		# Dump the public data tables from the primary database.
		args << config.fetch(:database)
		args += %w(species colors zones) # manual constants
		args += %w(alt_styles items parents_swf_assets pet_states pet_types
		           swf_assets) # from modeling

		# Set up a shell, and register the commands we need.
		Shell.def_system_command("mysqldump")
		Shell.def_system_command("gzip")
		sh = Shell.new

		# Ensure the output directory exists.
		dest_path.dirname.mkpath

		# Run mysqldump, pipe it into gzip, and output to the destination file.
		sh.transact do
			sh.mysqldump(*args) | sh.gzip("-c") > dest_path.to_s
		end

		puts "Saved dump to #{dest_path}"

		# Link this latest dump as `latest.sql.gz`.
		latest_path = Rails.configuration.public_data_root / "latest.sql.gz"
		File.unlink(latest_path) if File.symlink?(latest_path)
		File.symlink(filename, latest_path)

		puts "Linked dump to #{latest_path}"
	end

	desc "Pull and import the latest public data from production (dev only)"
	task :pull => ["db:abort_if_pending_migrations", :environment] do
		unless Rails.env.development?
			raise "Can only pull public data in development mode! This helps us " +
				"ensure we won't overwrite the production database accidentally."
		end

		args = []

		# The connection details for our database!
		config = ApplicationRecord.connection_db_config.configuration_hash
		args << "--host=#{config[:host]}" if config[:host]
		args << "--ssl=false" # SSL is the default for recent MariaDB; override!
		args << "--user=#{config[:username]}" if config[:username]
		args << "--password=#{config[:password]}" if config[:password]
		args << "--database=#{config.fetch(:database)}"

		# Set up a shell, and register the commands we need.
		Shell.def_system_command("mysql")
		Shell.def_system_command("gunzip")
		sh = Shell.new

		URI.open("https://impress.openneo.net/public-data/latest.sql.gz") do |file|
			# Pipe the latest public data SQL into `gunzip` to unpack it, then pipe
			# it into mysql to execute it.
			#
			# NOTE: We need `open(file)` to wrap it in a plain `File` object, so the
			# `Shell` will recognize it correctly! It doesn't accept `Tempfile`.
			sh.transact do
				(sh.gunzip("-c") < open(file)) | sh.mysql(*args)
			end
		end
	end
end
