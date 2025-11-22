# frozen_string_literal: true

module Sqlite
  module SchemaHelpers
    module_function

    def sanitize_expression(expr)
      sanitized = expr.to_s.dup
      return sanitized if sanitized.empty?

      sanitized = remove_casts(sanitized)
      sanitized = remove_wrapping_parentheses(sanitized)
      sanitized = remove_function_wrappers(sanitized)
      sanitized = sanitized.gsub(/\s+/, " ").strip
      sanitized = remove_wrapping_parentheses(sanitized)
      sanitized
    end

    def sanitize_partial_index(expr)
      sanitized = sanitize_expression(expr)
      return nil if sanitized.empty?

      equality_match = sanitized.match(/\A"?([a-zA-Z0-9_\.]+)"?\s*=\s*'?([^']+)'?\z/)
      return "#{equality_match[1]} = '#{equality_match[2]}'" if equality_match

      null_match = sanitized.match(/\A"?([a-zA-Z0-9_\.]+)"?\s+IS\s+(NOT\s+)?NULL\z/i)
      return "#{null_match[1]} IS #{null_match[2]}NULL".strip.upcase if null_match

      sanitized
    end

    def blank?(value)
      value.nil? || (value.respond_to?(:empty?) && value.empty?)
    end

    def remove_casts(source)
      source.gsub(/::[a-zA-Z0-9_]+/, "")
            .gsub(/CAST\(([^)]+) AS [^)]+\)/i, '\1')
    end
    private_class_method :remove_casts

    def remove_function_wrappers(source)
      source.gsub(/lower\(([^()]+)\)/i) { sanitize_expression(Regexp.last_match(1)) }
            .gsub(/upper\(([^()]+)\)/i) { sanitize_expression(Regexp.last_match(1)) }
    end
    private_class_method :remove_function_wrappers

    def remove_wrapping_parentheses(source)
      trimmed = source.strip
      while trimmed.start_with?("(") && trimmed.end_with?(")")
        inner = trimmed[1..-2].strip
        break if inner.empty? || matching_parentheses?(trimmed) == false

        trimmed = inner
      end
      trimmed
    end
    private_class_method :remove_wrapping_parentheses

    def matching_parentheses?(string)
      depth = 0
      string.each_char do |char|
        depth += 1 if char == "("
        depth -= 1 if char == ")"
        return false if depth.negative?
      end
      depth.zero?
    end
    private_class_method :matching_parentheses?
  end
end


