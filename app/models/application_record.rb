class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  class << self
    def sqlite_adapter?
      connection_db_config&.adapter == "sqlite3"
    rescue ActiveRecord::ConnectionNotEstablished
      config = ActiveRecord::Base.configurations.configs_for(
        env_name: Rails.env, name: "primary", include_replicas: false
      ).first
      config&.adapter == "sqlite3"
    end

    def ilike(column_name, term)
      sanitized = ActiveRecord::Base.sanitize_sql_like(term.to_s)
      pattern = "%#{sanitized}%"

      if sqlite_adapter?
        lowered_column = Arel::Nodes::NamedFunction.new("LOWER", [ arel_table[column_name] ])
        lowered_column.matches("%#{sanitized.downcase}%")
      else
        arel_table[column_name].matches(pattern, nil, true)
      end
    end
  end
end
