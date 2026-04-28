ENV["RAILS_ENV"] ||= "test"
ENV["API_KEY"] ||= "integration-test-api-key-secret"

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors, with: :threads)
  end
end
