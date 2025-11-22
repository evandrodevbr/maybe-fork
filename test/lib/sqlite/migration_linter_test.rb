# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/sqlite/migration_linter")

class SqliteMigrationLinterTest < ActiveSupport::TestCase
  def setup
    @tmp_dir = Rails.root.join("tmp/sqlite_linter_tests")
    FileUtils.mkdir_p(@tmp_dir)
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_detects_forbidden_patterns
    file = @tmp_dir.join("20240101000000_example.rb")
    File.write(file, <<~RUBY)
      class Example < ActiveRecord::Migration[7.2]
        def change
          enable_extension "pgcrypto"
          create_table :resources do |t|
            t.uuid :identifier
            t.jsonb :metadata
            t.string :tags, array: true
          end
        end
      end
    RUBY

    violations = Sqlite::MigrationLinter.new(file).violations
    assert_equal 4, violations.size
    assert_includes violations.map { |v| v[:message] }, "Avoid `t.uuid`; use `sqlite_uuid` helper or `t.string`."
  end

  def test_passes_clean_migration
    file = @tmp_dir.join("20240102000000_example.rb")
    File.write(file, <<~RUBY)
      class Example < ActiveRecord::Migration[7.2]
        def change
          create_table :resources, id: :string do |t|
            t.text :metadata
          end
        end
      end
    RUBY

    violations = Sqlite::MigrationLinter.new(file).violations
    assert_empty violations
  end
end


