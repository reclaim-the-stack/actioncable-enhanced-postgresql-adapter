# frozen_string_literal: true

require "debug"
begin
  require "active_support/testing/strict_warnings"
rescue LoadError
  nil
end
require "action_cable"
require "active_support/testing/autorun"
require "active_support/testing/method_call_assertions"

require "minitest/reporters"
Minitest::Reporters.use!

# Set test adapter and logger
ActionCable.server.config.cable = { "adapter" => "test" }
ActionCable.server.config.logger = Logger.new(nil)

class ActionCable::TestCase < ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions

  def wait_for_async
    wait_for_executor Concurrent.global_io_executor
  end

  def run_in_eventmachine
    yield
    wait_for_async
  end

  def wait_for_executor(executor)
    # do not wait forever, wait 2s
    timeout = 2
    until executor.completed_task_count == executor.scheduled_task_count
      sleep 0.1
      timeout -= 0.1
      raise "Executor could not complete all tasks in 2 seconds" unless timeout > 0
    end
  end
end
