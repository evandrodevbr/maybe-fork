# frozen_string_literal: true

module Sqlite
  class MigrationLinter
    VIOLATIONS = {
      /t\.uuid\b/ => "Avoid `t.uuid`; use `sqlite_uuid` helper or `t.string`.",
      /:jsonb\b/ => "SQLite does not support `:jsonb`; use serialized TEXT columns.",
      /array:\s*true/ => "Array columns are not supported; use join tables or serialized arrays.",
      /enable_extension\b/ => "Extensions are PostgreSQL-specific.",
      /create_enum\b/ => "Enums are PostgreSQL-specific. Use check constraints or simple strings."
    }.freeze

    attr_reader :files

    def initialize(files)
      @files = Array(files)
    end

    def violations
      files.flat_map { |file| inspect_file(file) }
    end

    private
      def inspect_file(file)
        content = File.read(file)
        VIOLATIONS.filter_map do |regex, message|
          next unless content.match?(regex)

          {
            file: relative_path(file),
            message: message,
            pattern: regex.source
          }
        end
      end

      def relative_path(file)
        Pathname.new(file).relative_path_from(Rails.root).to_s
      end
  end
end


