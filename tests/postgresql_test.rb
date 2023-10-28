# frozen_string_literal: true

require_relative "test_helper"
require_relative "common"
require_relative "channel_prefix"

require "active_record"

require "action_cable/subscription_adapter/enhanced_postgresql"

class PostgresqlAdapterTest < ActionCable::TestCase
  include CommonSubscriptionAdapterTest
  include ChannelPrefixTest

  def setup
    database_config = { "adapter" => "postgresql", "database" => "actioncable_enhanced_postgresql_test" }

    # Create the database unless it already exists
    begin
      ActiveRecord::Base.establish_connection database_config.merge("database" => "postgres")
      ActiveRecord::Base.connection.create_database database_config["database"], encoding: "utf8"
    rescue ActiveRecord::DatabaseAlreadyExists
    end

    # Connect to the database
    ActiveRecord::Base.establish_connection database_config

    begin
      ActiveRecord::Base.connection.connect!
    rescue
      @rx_adapter = @tx_adapter = nil
      skip "Couldn't connect to PostgreSQL: #{database_config.inspect}"
    end

    super
  end

  def teardown
    super

    ActiveRecord::Base.connection_handler.clear_all_connections!
  end

  def cable_config
    { adapter: "enhanced_postgresql", payload_encryptor_secret: SecureRandom.hex(16) }
  end

  def test_clear_active_record_connections_adapter_still_works
    server = ActionCable::Server::Base.new
    server.config.cable = cable_config.with_indifferent_access
    server.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }

    adapter_klass = Class.new(server.config.pubsub_adapter) do
      def active?
        !@listener.nil?
      end
    end

    adapter = adapter_klass.new(server)

    subscribe_as_queue("channel", adapter) do |queue|
      adapter.broadcast("channel", "hello world")
      assert_equal "hello world", queue.pop
    end

    ActiveRecord::Base.connection_handler.clear_reloadable_connections!

    assert adapter.active?
  end

  def test_default_subscription_connection_identifier
    subscribe_as_queue("channel") { }

    identifiers = ActiveRecord::Base.connection.exec_query("SELECT application_name FROM pg_stat_activity").rows
    assert_includes identifiers, ["ActionCable-PID-#{$$}"]
  end

  def test_custom_subscription_connection_identifier
    server = ActionCable::Server::Base.new
    server.config.cable = cable_config.merge(id: "hello-world-42").with_indifferent_access
    server.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }

    adapter = server.config.pubsub_adapter.new(server)

    subscribe_as_queue("channel", adapter) { }

    identifiers = ActiveRecord::Base.connection.exec_query("SELECT application_name FROM pg_stat_activity").rows
    assert_includes identifiers, ["hello-world-42"]
  end

  # Postgres has a NOTIFY payload limit of 8000 bytes which requires special handling to avoid
  # "PG::InvalidParameterValue: ERROR: payload string too long" errors.
  def test_large_payload_broadcast
    large_payloads_table = ActionCable::SubscriptionAdapter::EnhancedPostgresql::LARGE_PAYLOADS_TABLE
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      connection.execute("DROP TABLE IF EXISTS #{large_payloads_table}")
    end

    server = ActionCable::Server::Base.new
    server.config.cable = cable_config.with_indifferent_access
    server.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }
    adapter = server.config.pubsub_adapter.new(server)

    large_payload = "a" * (ActionCable::SubscriptionAdapter::EnhancedPostgresql::MAX_NOTIFY_SIZE + 1)

    subscribe_as_queue("channel", adapter) do |queue|
      adapter.broadcast("channel", large_payload)

      # The large payload is stored in the database at this point
      assert_equal 1, ActiveRecord::Base.connection.query("SELECT COUNT(*) FROM #{large_payloads_table}").first.first

      assert_equal large_payload, queue.pop
    end
  end

  def test_automatic_payload_deletion
    inserts_per_delete = ActionCable::SubscriptionAdapter::EnhancedPostgresql::INSERTS_PER_DELETE
    large_payloads_table = ActionCable::SubscriptionAdapter::EnhancedPostgresql::LARGE_PAYLOADS_TABLE
    large_payload = "a" * (ActionCable::SubscriptionAdapter::EnhancedPostgresql::MAX_NOTIFY_SIZE + 1)
    pg_conn = ActiveRecord::Base.connection.raw_connection

    # Prep the database so that we are one insert away from a delete. All but one entry should be old
    # enough to be reaped on the next broadcast.
    pg_conn.exec("DROP TABLE IF EXISTS #{large_payloads_table}")
    pg_conn.exec(ActionCable::SubscriptionAdapter::EnhancedPostgresql::CREATE_LARGE_TABLE_QUERY)

    insert_query = "INSERT INTO #{large_payloads_table} (payload, created_at) VALUES ('a', $1) RETURNING id"
    # Insert 98 rows older than 10 minutes
    (inserts_per_delete - 2).times do
      pg_conn.exec_params(insert_query, [11.minutes.ago])
    end
    # Insert 1 row newer than 10 minutes
    new_payload_id = pg_conn.exec_params(insert_query, [9.minutes.ago]).first.fetch("id")

    # Sanity check that the auto incrementing ID is what we expect
    assert_equal inserts_per_delete - 1, new_payload_id

    server = ActionCable::Server::Base.new
    server.config.cable = cable_config.with_indifferent_access
    server.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }
    adapter = server.config.pubsub_adapter.new(server)

    adapter.broadcast("channel", large_payload)

    remaining_payload_ids = pg_conn.query("SELECT id FROM #{large_payloads_table} ORDER BY id").values.flatten
    assert_equal [inserts_per_delete - 1, inserts_per_delete], remaining_payload_ids
  end
end
