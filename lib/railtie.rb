class ActionCable::SubscriptionAdapter::EnhancedPostgresql
  class Railtie < ::Rails::Railtie
    initializer "action_cable.enhanced_postgresql_adapter" do
      ActiveSupport.on_load(:active_record) do
        large_payloads_table = ActionCable::SubscriptionAdapter::EnhancedPostgresql::LARGE_PAYLOADS_TABLE
        ActiveRecord::SchemaDumper.ignore_tables << large_payloads_table
      end
    end
  end
end
