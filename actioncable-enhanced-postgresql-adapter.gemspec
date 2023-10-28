Gem::Specification.new do |spec|
  spec.name = "actioncable-enhanced-postgresql-adapter"
  spec.version = "1.0.0"
  spec.authors = ["David Backeus"]
  spec.email = ["david.backeus@mynewsdesk.com"]

  spec.summary = "ActionCable adapter for PostgreSQL that enhances the default."
  spec.description = "Handles the 8000 byte limit for PostgreSQL NOTIFY payloads"
  spec.homepage = "https://github.com/dbackeus/actioncable-enhanced-postgresql-adapter"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/CHANGELOG.md"

  spec.files = %w[README.md CHANGELOG.md actioncable-enhanced-postgresql-adapter.gemspec] + Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  spec.add_dependency "actioncable", ">= 7.1"
  spec.add_dependency "activerecord", ">= 7.1"
  spec.add_dependency "pg", "~> 1.5"
end