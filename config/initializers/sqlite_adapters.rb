# frozen_string_literal: true

ActiveSupport.on_load(:active_record) do
  primary_config = ActiveRecord::Base.configurations.configs_for(
    env_name: Rails.env, name: "primary", include_replicas: false
  ).first

  next unless primary_config&.adapter == "sqlite3"

  require "active_record/connection_adapters/sqlite3_adapter"

  module MaybeSqliteAdapterExtensions
    def native_database_types
      super.merge(jsonb: { name: "TEXT" })
    end

    def add_column(table_name, column_name, type, **options)
      type, options = normalize_column_type_and_options(type, options)
      super(table_name, column_name, type, **options)
    end

    def change_column(table_name, column_name, type, **options)
      type, options = normalize_column_type_and_options(type, options)
      super(table_name, column_name, type, **options)
    end

    private
      def normalize_column_type_and_options(type, options)
        options = options.dup

        if type == :jsonb
          type = :text
          options[:default] = options[:default].to_json if options[:default].is_a?(Hash) || options[:default].is_a?(Array)
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

  ActiveRecord::Type.register(:jsonb, ActiveRecord::Type::Json)
end

