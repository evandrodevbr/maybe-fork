# frozen_string_literal: true

require "test_helper"
require Rails.root.join("config/initializers/sqlite_adapters")

class SqliteCreateTableDefinitionTest < ActiveSupport::TestCase
  class DummyAdapter
    attr_reader :captured_args, :captured_kwargs

    def create_table_definition(*args, **kwargs)
      @captured_args = args
      @captured_kwargs = kwargs
      :super_called
    end
  end

  def setup
    @adapter_class = Class.new(DummyAdapter) do
      prepend MaybeSqliteAdapterExtensions
    end
    @adapter = @adapter_class.new
  end

  def test_handles_four_arguments
    result = @adapter.create_table_definition(:accounts, false, { id: :uuid, primary_key: :uuid }, nil)

    assert_equal :super_called, result
    args = @adapter.captured_args
    assert_equal :accounts, args[0]
    assert_equal false, args[1]
    assert_equal({ id: :text, primary_key: :text }, args[2])
    assert_nil args[3]
  end

  def test_handles_three_arguments
    result = @adapter.create_table_definition(:accounts, false, { primary_key: :uuid })

    assert_equal :super_called, result
    assert_equal({ primary_key: :text }, @adapter.captured_args[2])
  end

  def test_handles_keyword_options
    result = @adapter.create_table_definition(:accounts, options: { id: :uuid }, temporary: false)

    assert_equal :super_called, result
    assert_equal false, @adapter.captured_kwargs[:temporary]
    assert_equal({ id: :text }, @adapter.captured_kwargs[:options])
  end

  def test_handles_hash_with_options_key
    result = @adapter.create_table_definition(:accounts, temporary: false, options: { primary_key: :uuid })

    assert_equal :super_called, result
    assert_equal({ primary_key: :text }, @adapter.captured_kwargs[:options])
  end

  def test_passthrough_when_no_options
    result = @adapter.create_table_definition(:accounts, false)

    assert_equal :super_called, result
    assert_equal [:accounts, false], @adapter.captured_args
  end
end


