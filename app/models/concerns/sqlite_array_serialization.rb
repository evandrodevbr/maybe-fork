# frozen_string_literal: true

module SqliteArraySerialization
  extend ActiveSupport::Concern

  included do
    class_attribute :sqlite_serialized_array_attributes, instance_accessor: false, default: []
    class_attribute :sqlite_array_defaults_callback_registered, instance_accessor: false, default: false
  end

  class_methods do
    def sqlite_array_attribute(*attributes)
      return unless ApplicationRecord.sqlite_adapter?

      normalized_attributes = attributes.map(&:to_sym)
      self.sqlite_serialized_array_attributes |= normalized_attributes

      normalized_attributes.each do |attribute|
        serialize attribute, type: Array
      end

      unless sqlite_array_defaults_callback_registered
        after_initialize :ensure_sqlite_array_defaults
        self.sqlite_array_defaults_callback_registered = true
      end
    end
  end

  private
    def ensure_sqlite_array_defaults
      self.class.sqlite_serialized_array_attributes.each do |attribute|
        value = public_send(attribute)
        value = [] if value.nil?
        write_attribute(attribute, value)
      end
    end
end

