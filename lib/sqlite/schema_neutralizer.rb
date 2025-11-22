# frozen_string_literal: true

require_relative "schema_helpers"

module Sqlite
  class SchemaNeutralizer
    def initialize(content)
      @content = content.dup
    end

    def call
      remove_extension_lines
      remove_enum_lines
      replace_casts
      replace_gen_random_uuid_defaults
      replace_virtual_columns
      sanitize_index_definitions
      sanitize_partial_index_clauses
      normalize_whitespace
      @content
    end

    private
      def remove_extension_lines
        @content.gsub!(/^\s*enable_extension\s+"[^"]+"\s*\n/, "")
      end

      def remove_enum_lines
        @content.gsub!(/^\s*create_enum\s+".*"\s*,\s*\[.*\]\s*\n/, "")
      end

      def replace_casts
        @content.gsub!(/::[a-zA-Z0-9_]+/, "")
      end

      def replace_gen_random_uuid_defaults
        @content.gsub!(/default:\s*->\s*\{\s*"gen_random_uuid\(\)"\s*\}/, "default: nil")
      end

      def replace_virtual_columns
        @content.gsub!(/(\s*)t\.virtual\s+"([^"]+)",\s*type:\s+:([a-z_]+)([^\\n]*)/) do
          indentation = Regexp.last_match(1)
          column = Regexp.last_match(2)
          type = Regexp.last_match(3)
          remainder = Regexp.last_match(4)

          cleaned_remainder = remainder.gsub(/,\s*stored:\s*(true|false)/, "")
                                       .gsub(/,\s*as:\s*[^,]+/, "")
          "#{indentation}t.#{type} \"#{column}\"#{cleaned_remainder}"
        end
      end

      def sanitize_index_definitions
        @content.gsub!(/t\.index\s+"([^"]+)"/) do
          sanitized = Sqlite::SchemaHelpers.sanitize_expression(Regexp.last_match(1))
          %(t.index "#{sanitized}")
        end
      end

      def sanitize_partial_index_clauses
        @content.gsub!(/,\s*where:\s*"([^"]*)"/) do
          sanitized = Sqlite::SchemaHelpers.sanitize_partial_index(Regexp.last_match(1))
          Sqlite::SchemaHelpers.blank?(sanitized) ? "" : %(, where: "#{sanitized}")
        end
      end

      def normalize_whitespace
        @content.gsub!(/\n{3,}/, "\n\n")
      end
  end
end


