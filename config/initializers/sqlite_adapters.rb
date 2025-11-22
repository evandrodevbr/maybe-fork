# frozen_string_literal: true

require Rails.root.join("lib/sqlite/schema_helpers")

ActiveSupport.on_load(:active_record) do
  configs_for_args = { env_name: Rails.env, name: "primary" }

  if ActiveRecord::Base.configurations.method(:configs_for).parameters.any? { |type, name| type == :key && name == :include_replicas }
    configs_for_args[:include_replicas] = false
  end

  configs_for_result = ActiveRecord::Base.configurations.configs_for(**configs_for_args)
  primary_config = if configs_for_result.respond_to?(:first)
    configs_for_result.first
  else
    configs_for_result
  end

  next unless primary_config&.adapter == "sqlite3"

  require "active_record/connection_adapters/sqlite3_adapter"

  module MaybeSqliteAdapterExtensions
    def native_database_types
      super.merge(
        jsonb: { name: "TEXT" },
        uuid: { name: "TEXT" }
      )
    end

    def add_column(table_name, column_name, type, **options)
      type, options = normalize_column_type_and_options(type, options)
      super(table_name, column_name, type, **options)
    end

    def change_column(table_name, column_name, type, **options)
      type, options = normalize_column_type_and_options(type, options)
      super(table_name, column_name, type, **options)
    end

    def create_table_definition(*args, **kwargs, &block)
      args = args.dup
      kwargs = kwargs.dup

      if kwargs.key?(:options) && kwargs[:options].is_a?(Hash)
        kwargs[:options] = normalize_table_options(kwargs[:options])
      elsif args.length >= 3 && args[2].is_a?(Hash)
        args[2] = normalize_table_options(args[2])
      elsif args.length >= 2 && args.last.is_a?(Hash) && args.last.key?(:options)
        hash_with_options = args.last.dup
        hash_with_options[:options] = normalize_table_options(hash_with_options[:options])
        args[-1] = hash_with_options
      end

      super(*args, **kwargs, &block)
    end

    def enable_extension(_name)
      # No-op for compatibility with schema.rb
    end

    def disable_extension(_name)
      # No-op
    end

    def extension_enabled?(_name)
      false
    end

    def create_enum(_name, _values)
      # No-op; SQLite lacks native enums
    end

    def drop_enum(_name, _options = {})
      # No-op
    end

    private
      def normalize_table_options(options)
        return options unless options.is_a?(Hash)

        normalized = options.dup

        if normalized[:id] == :uuid
          normalized[:id] = :text
          if normalized[:default].respond_to?(:call) || normalized[:default].to_s.include?("gen_random_uuid")
            normalized.delete(:default)
          end
        end

        primary_key = normalized[:primary_key]
        if primary_key.is_a?(Array)
          normalized[:primary_key] = primary_key.map { |key| key == :uuid ? :text : key }
        elsif primary_key == :uuid
          normalized[:primary_key] = :text
        end

        normalized
      end

      def normalize_column_type_and_options(type, options)
        options = options.dup

        if type == :jsonb
          type = :text
          options[:default] = options[:default].to_json if options[:default].is_a?(Hash) || options[:default].is_a?(Array)
        end

        if type == :uuid
          type = :text
          options.delete(:limit)
          if options[:default].respond_to?(:call) || options[:default].to_s.include?("gen_random_uuid")
            options.delete(:default)
          end
        end

        if options[:array]
          default = options.key?(:default) ? Array(options[:default]) : []
          options = options.except(:array)
          options[:default] = default.to_json
          type = :text
        end

        [ type, options ]
      end
  end

  module MaybeSqliteTableDefinitionExtensions
    def column(name, type, index: nil, **options)
      type, options = normalize_column_type_and_options(type, options)
      super
    end

    private
      def normalize_column_type_and_options(type, options)
        options = options.dup

        if type == :jsonb
          type = :text
          options[:default] = options[:default].to_json if options[:default].is_a?(Hash) || options[:default].is_a?(Array)
        end

        if type == :uuid
          type = :text
          options.delete(:limit)
          if options[:default].respond_to?(:call) || options[:default].to_s.include?("gen_random_uuid")
            options.delete(:default)
          end
        end

        if options[:array]
          default = options.key?(:default) ? Array(options[:default]) : []
          options = options.except(:array)
          options[:default] = default.to_json
          type = :text
        end

        [ type, options ]
      end
  end

  ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(MaybeSqliteAdapterExtensions)
  ActiveRecord::ConnectionAdapters::SQLite3::TableDefinition.prepend(MaybeSqliteTableDefinitionExtensions)

  ActiveRecord::Schema.define_version = ActiveRecord::Schema::Migration::Compatibility::Version.new(ActiveRecord::Migrator.current_version) if ActiveRecord::Schema.respond_to?(:define_version)

  if defined?(ActiveRecord::Schema)
    schema_singleton = ActiveRecord::Schema.singleton_class

    unless schema_singleton.method_defined?(:enable_extension)
      schema_singleton.define_method(:enable_extension) { |_name| }
    end

    unless schema_singleton.method_defined?(:disable_extension)
      schema_singleton.define_method(:disable_extension) { |_name| }
    end

    unless schema_singleton.method_defined?(:extension_enabled?)
      schema_singleton.define_method(:extension_enabled?) { |_name| false }
    end

    unless schema_singleton.method_defined?(:create_enum)
      schema_singleton.define_method(:create_enum) { |_name, _values| }
    end

    unless schema_singleton.method_defined?(:drop_enum)
      schema_singleton.define_method(:drop_enum) { |_name, _options = {}| }
    end
  end

  ActiveRecord::ConnectionAdapters::SQLite3::TableDefinition.class_eval do
    def uuid(name, **options)
      column(name, :uuid, **options)
    end

    def jsonb(name, **options)
      column(name, :jsonb, **options)
    end

    def virtual(name, type:, as:, stored: false, **options)
      # SQLite doesn't support virtual generated columns with complex expressions;
      # degrade gracefully to a regular column.
      column(name, type, **options)
    end

    def index(column_name, options = {})
      sanitized_column_name =
        if column_name.is_a?(String)
          sanitized = Sqlite::SchemaHelpers.sanitize_expression(column_name)
          Sqlite::SchemaHelpers.blank?(sanitized) ? column_name : sanitized
        else
          column_name
        end

      sanitized_options = options.transform_values do |value|
        value.is_a?(String) ? Sqlite::SchemaHelpers.sanitize_expression(value) : value
      end

      if sanitized_options.key?(:where)
        sanitized_where = Sqlite::SchemaHelpers.sanitize_partial_index(sanitized_options[:where])
        sanitized_where = nil if Sqlite::SchemaHelpers.blank?(sanitized_where)
        sanitized_options[:where] = sanitized_where
      end

      sanitized_options.compact!

      super(sanitized_column_name, **sanitized_options)
    end
  end

  ActiveRecord::Type.register(:jsonb, ActiveRecord::Type::Json)
end

