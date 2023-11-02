Gem::Specification.new do |spec|
  spec.name = "actioncable-enhanced-postgresql-adapter"
  spec.version = "1.0.1"
  spec.authors = ["David Backeus"]
  spec.email = ["david.backeus@mynewsdesk.com"]

  spec.summary = "ActionCable adapter for PostgreSQL that enhances the default."
  spec.description = "Enhances ActionCable's built in Postgres adapter with handling of the 8000 byte limit for PostgreSQL NOTIFY payloads and allows usage without ActiveRecord."
  spec.homepage = "https://github.com/reclaim-the-stack/actioncable-enhanced-postgresql-adapter"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/CHANGELOG.md"
  }

  spec.files = %w[README.md CHANGELOG.md actioncable-enhanced-postgresql-adapter.gemspec] + Dir["lib/**/*"]

  spec.add_dependency "actioncable", ">= 6.0"
  spec.add_dependency "connection_pool", ">= 2.2.5" # Ruby 2.7 compatible version
  spec.add_dependency "pg", "~> 1.5"
end