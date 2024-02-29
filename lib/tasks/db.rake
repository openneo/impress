namespace :db do
	desc "Generate SQL to convert all tables and columns to utf8mb4"
	task :utf8_migration => :environment do
		target_charset = "utf8mb4"
		target_collation = "utf8mb4_unicode_520_ci"

		db = ApplicationRecord.connection

		# Don't mess with ActiveRecord's internal tables!
		tables = db.tables.reject { |t| t.start_with? "ar_internal_" }

		ups = []
		downs = []
		tables.sort.each do |table|
			# If the table's default charset/collation doesn't match our goal, we'll
			# modify it!
			db.table_options(table) => {charset:, collation:}
			if charset != target_charset || collation != target_collation
				ups << "ALTER TABLE #{table} CONVERT TO CHARACTER SET " +
					"#{target_charset} COLLATE #{target_collation}"
				downs << "ALTER TABLE #{table} CONVERT TO CHARACTER SET " +
					"#{charset} COLLATE #{collation}"
			end
		end

		puts <<~MIGRATION_RB
			reversible do |direction|
				direction.up do
			#{sql_as_ruby(ups).indent(2, "\t")}
				end

				direction.down do
			#{sql_as_ruby(downs).indent(2, "\t")}
				end
			end
		MIGRATION_RB
	end
end

def sql_as_ruby(statements)
	statements.map do |sql|
		<<~EXECUTE_RB
			execute <<-SQL
				#{sql}
			SQL
		EXECUTE_RB
	end.join("")
end
