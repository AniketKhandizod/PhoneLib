ENV["RAILS_ENV"] ||= "test"
# Integration tests run from 127.0.0.1; production default 27.107.44.138 would block them.
ENV["ALLOWED_CLIENT_IP"] ||= "127.0.0.1"

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors, with: :threads)
  end
end
