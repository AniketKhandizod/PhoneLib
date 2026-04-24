ENV["RAILS_ENV"] ||= "test"
ENV["API_BEARER_TOKEN"] ||= "test-bearer"

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors, with: :threads)
  end
end
