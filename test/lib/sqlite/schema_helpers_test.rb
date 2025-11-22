# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/sqlite/schema_helpers")
require Rails.root.join("lib/sqlite/schema_neutralizer")

class SqliteSchemaHelpersTest < ActiveSupport::TestCase
  def test_sanitize_expression_removes_casts_and_functions
    expression = "lower((accounts.name)::text)"
    assert_equal "accounts.name", Sqlite::SchemaHelpers.sanitize_expression(expression)
  end

  def test_sanitize_expression_unwraps_parentheses
    expression = "((account_id))"
    assert_equal "account_id", Sqlite::SchemaHelpers.sanitize_expression(expression)
  end

  def test_sanitize_partial_index_equality
    expression = "((type)::text = 'FamilyMerchant'::text)"
    assert_equal "type = 'FamilyMerchant'", Sqlite::SchemaHelpers.sanitize_partial_index(expression)
  end

  def test_sanitize_partial_index_null_check
    expression = "(deleted_at IS NULL)"
    assert_equal "DELETED_AT IS NULL", Sqlite::SchemaHelpers.sanitize_partial_index(expression)
  end

  def test_blank_helper
    assert Sqlite::SchemaHelpers.blank?(nil)
    assert Sqlite::SchemaHelpers.blank?("")
    refute Sqlite::SchemaHelpers.blank?("value")
  end

  def test_schema_neutralizer_removes_extension_and_casts
    schema_fragment = <<~RUBY
      ActiveRecord::Schema[7.2].define(version: 2024_01_01_000001) do
        enable_extension "pgcrypto"
        create_enum "account_status", ["ok", "error"]

        create_table "merchants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
          t.virtual "classification", type: :string, as: "lower((type)::text)", stored: true
          t.index "lower((name)::text)", name: "index_merchants_on_lower_name"
          t.index ["family_id", "name"], name: "index_merchants_on_family_id_and_name", unique: true, where: "((type)::text = 'FamilyMerchant'::text)"
        end
      end
    RUBY

    neutralized = Sqlite::SchemaNeutralizer.new(schema_fragment).call

    refute_includes neutralized, "enable_extension"
    refute_includes neutralized, "create_enum"
    refute_includes neutralized, "gen_random_uuid"
    assert_includes neutralized, 't.string "classification"'
    assert_includes neutralized, 't.index "merchants.name"'
    assert_includes neutralized, 'where: "type = \'FamilyMerchant\'"'
  end
end

