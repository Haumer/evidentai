ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Rails 7.1 line filtering expects older minitest run arity.
# Keep old behavior when options hash is present and delegate otherwise.
if defined?(Rails::LineFiltering)
  module Rails
    module LineFiltering
      def run(*args)
        if args.length <= 2
          reporter, options = args
          options ||= {}
          options = options.merge(filter: Rails::TestUnit::Runner.compose_filter(self, options[:filter]))
          super(reporter, options)
        else
          super(*args)
        end
      end
    end
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
