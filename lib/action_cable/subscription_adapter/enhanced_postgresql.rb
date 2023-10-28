# freeze_string_literal: true

require "action_cable/subscription_adapter/postgresql"

module ActionCable
  module SubscriptionAdapter
    class EnhancedPostgresql < PostgreSQL
      MAX_NOTIFY_SIZE = 7997 # documented as 8000 bytes, but there appears to be some overhead in transit
      LARGE_PAYLOAD_PREFIX = "__large_payload:"
      INSERTS_PER_DELETE = 100 # execute DELETE query every N inserts

      LARGE_PAYLOADS_TABLE = "action_cable_large_payloads"
      CREATE_LARGE_TABLE_QUERY = <<~SQL
        CREATE UNLOGGED TABLE IF NOT EXISTS #{LARGE_PAYLOADS_TABLE} (
          id SERIAL PRIMARY KEY,
          payload TEXT NOT NULL,
          created_at TIMESTAMP NOT NULL DEFAULT NOW()
        )
      SQL
      INSERT_LARGE_PAYLOAD_QUERY = "INSERT INTO #{LARGE_PAYLOADS_TABLE} (payload, created_at) VALUES ($1, $2) RETURNING id"
      SELECT_LARGE_PAYLOAD_QUERY = "SELECT payload FROM #{LARGE_PAYLOADS_TABLE} WHERE id = $1"
      DELETE_LARGE_PAYLOAD_QUERY = "DELETE FROM #{LARGE_PAYLOADS_TABLE} WHERE created_at < $1"

      def broadcast(channel, payload)
        with_broadcast_connection do |pg_conn|
          channel = pg_conn.escape_identifier(channel_identifier(channel))
          payload = pg_conn.escape_string(payload)

          if payload.bytesize > MAX_NOTIFY_SIZE
            payload_id = insert_large_payload(pg_conn, payload)

            if payload_id % INSERTS_PER_DELETE == 0
              pg_conn.exec_params(DELETE_LARGE_PAYLOAD_QUERY, [10.minutes.ago])
            end

            # Encrypt payload_id to prevent simple integer ID spoofing
            encrypted_payload_id = payload_encryptor.encrypt_and_sign(payload_id)

            payload = "#{LARGE_PAYLOAD_PREFIX}#{encrypted_payload_id}"
          end

          pg_conn.exec("NOTIFY #{channel}, '#{payload}'")
        end
      end

      def payload_encryptor
        @payload_encryptor ||= begin
          secret = @server.config.cable[:payload_encryptor_secret]
          secret ||= Rails.application.secrets.secret_key_base if Object.const_defined?("Rails")
          secret ||= ENV["SECRET_KEY_BASE"]

          raise ArgumentError, "Missing payload_encryptor_secret configuration for ActionCable EnhancedPostgresql adapter. You need to either explicitly configure it in cable.yml or set the SECRET_KEY_BASE environment variable." unless secret

          ActiveSupport::MessageEncryptor.new(secret)
        end
      end

      private

      def insert_large_payload(pg_conn, payload)
        result = pg_conn.exec_params(INSERT_LARGE_PAYLOAD_QUERY, [payload, Time.now])
        result.first.fetch("id")
      rescue PG::UndefinedTable
        pg_conn.exec(CREATE_LARGE_TABLE_QUERY)
        retry
      end

      # Override needed to ensure we reference our local Listener class
      def listener
        @listener || @server.mutex.synchronize { @listener ||= Listener.new(self, @server.event_loop) }
      end

      class Listener < PostgreSQL::Listener
        def invoke_callback(callback, message)
          if message.start_with?(LARGE_PAYLOAD_PREFIX)
            encrypted_payload_id = message.delete_prefix(LARGE_PAYLOAD_PREFIX)
            payload_id = @adapter.payload_encryptor.decrypt_and_verify(encrypted_payload_id)

            ActiveRecord::Base.connection_pool.with_connection do |connection|
              result = connection.raw_connection.exec_params(SELECT_LARGE_PAYLOAD_QUERY, [payload_id])
              message = result.first.fetch("payload")
            end
          end

          @event_loop.post { super }
        end
      end
    end
  end
end
