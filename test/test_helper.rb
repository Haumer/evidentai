ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# minitest 6 removed Object#stub used by existing tests in this project.
# Provide a minimal compatibility helper for class/object stubbing.
unless Object.method_defined?(:stub)
  class Object
    def stub(method_name, callable_or_value = nil)
      singleton = class << self; self; end

      had_original =
        singleton.method_defined?(method_name) ||
        singleton.private_method_defined?(method_name) ||
        singleton.protected_method_defined?(method_name)

      original_method = singleton.instance_method(method_name) if had_original

      singleton.define_method(method_name) do |*args, **kwargs, &block|
        if callable_or_value.respond_to?(:call)
          callable_or_value.call(*args, **kwargs, &block)
        else
          callable_or_value
        end
      end

      yield
    ensure
      singleton.send(:remove_method, method_name) rescue nil
      singleton.define_method(method_name, original_method) if had_original
    end
  end
end

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
