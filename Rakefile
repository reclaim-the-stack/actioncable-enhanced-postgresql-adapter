require "pg"

def postgres_ready?(url, timeout:, retry_interval: 0.1)
  start_time = Time.now

  loop do
    conn = PG.connect(url)
    conn.exec("SELECT 1")
    conn.close
    return true
  rescue PG::Error => e
    if Time.now - start_time > timeout
      puts "Failed to connect to PostgreSQL: #{e.message}"
      return false
    else
      sleep retry_interval
    end
  end
end

ENV["DB_USERNAME"] ||= "actioncable"
ENV["DB_PASSWORD"] ||= "actioncable"
ENV["DB_HOST"] ||= "localhost"
ENV["DB_PORT"] ||= "5432"

ENV["DB_URL"] ||= begin
  username = ENV.fetch("DB_USERNAME", "")
  password = ENV.fetch("DB_PASSWORD", "")
  host = ENV.fetch("DB_HOST", "localhost")
  port = ENV.fetch("DB_PORT", "5432")

  url = "postgresql://"
  unless username.empty?
    url += username
    url += ":#{password}" unless password.empty?
    url += "@"
  end
  url += host
  url += ":#{port}" unless port.empty?
  url
end

namespace :docker do
  task :up do
    `docker compose up -d`

    timeout = 10
    puts "* Waiting for PostgreSQL database to accepting connections"
    if postgres_ready?(ENV.fetch("DB_URL"), timeout: timeout)
      puts "* PostgreSQL database is up and accepting connections"
    else
      puts "* PostgreSQL database is not ready after #{timeout} seconds"
      `docker compose down -v`
      exit 1
    end
  end

  task :down do
    `docker compose down -v`
  end
end

task :test do
  system("bundle", "exec", "ruby", "test/postgresql_test.rb")
end

task "test:docker" => ["docker:down", "docker:up", "test", "docker:down"]

task default: "test:docker"
