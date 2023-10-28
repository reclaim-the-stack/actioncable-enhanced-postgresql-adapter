# actioncable-enhanced-postgresql-adapter

This gem provides an enhanced PostgreSQL adapter for ActionCable. It is based on the original PostgreSQL adapter, but adds support for the following features:
- Ability to broadcast payloads larger than 8000 bytes

## Installation

Add this line to your application's Gemfile:

```ruby
gem "actioncable-enhanced-postgresql-adapter", git: "https://github.com/reclaim-the-stack/actioncable-enhanced-postgresql-adapter"
```

## Usage

In your `config/cable.yml` file, change the adapter for relevant environments to `enhanced_postgresql`:

```yaml
development:
  adapter: enhanced_postgresql

production:
  adapter: enhanced_postgresql
```

## Approach

To overcome the 8000 bytes limit, we temporarily store large payloads in an unlogged database table named `action_cable_large_payloads`. The table is lazily created on first broadcast. Deletion of stale payloads (10 minutes or older) are deleted every 100 broadcasts.

Note that payloads smaller than 8000 bytes are sent directly via NOTIFY, as per the original adapter.
