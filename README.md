# actioncable-enhanced-postgresql-adapter

This gem provides an enhanced PostgreSQL adapter for ActionCable. It is based on the original PostgreSQL adapter, but includes the following enhancements:
- Ability to broadcast payloads larger than 8000 bytes
- Not dependent on ActiveRecord (but can still integrate with it if available)

### Approach

To overcome the 8000 bytes limit, we temporarily store large payloads in an [unlogged](https://www.crunchydata.com/blog/postgresl-unlogged-tables) database table named `action_cable_large_payloads`. The table is lazily created on first broadcast.

We then broadcast a payload in the style of `__large_payload:<encrypted-payload-id>`. The listener client then decrypts incoming ID's, fetches the original payload from the database, and replaces the temporary payload before invoking the subscriber callback.

ID encryption is done to prevent spoofing large payloads by manually broadcasting messages prefixed with `__large_payload:` with just an auto incrementing integer.

Note that payloads smaller than 8000 bytes are sent directly via NOTIFY, as per the original adapter.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "actioncable-enhanced-postgresql-adapter"
```

## Usage

In your `config/cable.yml` file, change the adapter for relevant environments to `enhanced_postgresql`:

```yaml
development:
  adapter: enhanced_postgresql

production:
  adapter: enhanced_postgresql
```

## Configuration

The following configuration options are available:

- `payload_encryptor_secret` - The secret used to encrypt large payload ID's. Defaults to `Rails.application.secret_key_base` or the `SECRET_KEY_BASE` environment variable unless explicitly specified.
- `url` - Set this if you want to use a different database than the one provided by ActiveRecord. Must be a valid PostgreSQL connection string.
- `connection_pool_size` - Set this in conjunction with `url` to set the size of the postgres connection pool used for broadcasts. Defaults to `RAILS_MAX_THREADS` environment variable or falls back to 5.

## Performance

For payloads smaller than 8000 bytes, which should cover the majority of cases, performance is identical to the original adapter.

When broadcasting large payloads, one has to consider the overhead of storing and fetching the payload from the database. For low frequency broadcasting, this overhead is likely negligible. But take care if you're doing very high frequency broadcasting.

Note that whichever ActionCable adapter you're using, sending large payloads with high frequency is an anti-pattern. Even Redis pub/sub has [limitations](https://redis.io/docs/reference/clients/#output-buffer-limits) to be aware of.

### Cleanup of large payloads

Deletion of stale payloads (2 minutes or older) are triggered every 100 large payload inserts. We do this by looking at the incremental ID generated on insert and checking if it is evenly divisible by 100. This approach avoids having to manually schedule cleanup jobs while striking a balance between performance and cleanup frequency.

## Development

- Clone repo
- `bundle install` to install dependencies
- Ensure you have docker-engine and run
  ```
  bundle exec rake
  ```

- Alternatively
  ```
  bundle exec rake test
  ```
- See `Rakefile` for environment variables that you can override
