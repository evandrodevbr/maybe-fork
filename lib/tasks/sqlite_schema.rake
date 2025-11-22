require Rails.root.join("lib/sqlite/schema_neutralizer")
require Rails.root.join("lib/sqlite/migration_linter")

namespace :db do
  namespace :schema do
    desc "Neutralize db/schema.rb for SQLite/Litestack compatibility"
    task neutralize: :environment do
      schema_path = Rails.root.join("db/schema.rb")

      unless File.exist?(schema_path)
        puts "[db:schema:neutralize] Schema file not found at #{schema_path}"
        next
      end

      original_content = File.read(schema_path)
      neutralized_content = Sqlite::SchemaNeutralizer.new(original_content).call

      if original_content == neutralized_content
        puts "[db:schema:neutralize] Schema already neutralized"
        next
      end

      File.write(schema_path, neutralized_content)
      puts "[db:schema:neutralize] Schema neutralized for SQLite compatibility"
    end
  end

  namespace :sqlite do
    desc "Lint migrations for SQLite/Litestack compatibility issues"
    task lint_migrations: :environment do
      files = Dir[Rails.root.join("db/migrate/**/*.rb")]
      violations = Sqlite::MigrationLinter.new(files).violations

      if violations.empty?
        puts "[db:sqlite:lint_migrations] No issues detected ✅"
      else
        puts "[db:sqlite:lint_migrations] Found SQLite incompatibilities:"
        violations.each do |violation|
          puts "  - #{violation[:file]}: #{violation[:message]} (pattern: #{violation[:pattern]})"
        end
        abort "[db:sqlite:lint_migrations] Please resolve the issues above."
      end
    end

    desc "Verify SQLite schema setup pipeline (drop/create/load)"
    task setup_check: :environment do
      ENV["DISABLE_DATABASE_ENVIRONMENT_CHECK"] = "1"
      %w[db:drop db:create db:schema:load].each do |task_name|
        puts "[db:sqlite:setup_check] Running #{task_name}"
        task = Rake::Task[task_name]
        task.reenable
        task.invoke
      rescue => e
        abort "[db:sqlite:setup_check] #{task_name} failed: #{e.message}"
      end

      puts "[db:sqlite:setup_check] SQLite setup verified successfully ✅"
    end
  end
end

