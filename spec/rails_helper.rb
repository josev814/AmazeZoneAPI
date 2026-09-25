require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

# Load support files (FactoryBot, custom matchers, etc.)
Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

# The test database is scratch space for the suite. Keep it in sync with the
# migrations. (Transactional fixtures are enabled explicitly in the RSpec
# configuration below.)
ActiveRecord::Migration.maintain_test_schema!

# Add additional initialization below.
RSpec.configure do |config|
  # Run examples in a random order to avoid order-dependent tests.
  config.order = :random
  Kernel.srand config.seed

  # Wrap each example in a transaction and roll it back afterwards, and make
  # request specs share the test thread's transaction so that data created in
  # the spec is visible to the (separate-thread) request. In rspec-rails 7.x
  # this defaults to nil/false, so it must be enabled explicitly - otherwise
  # records leak into the test database and requests can't see uncommitted
  # data (both of which we observed).
  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures  = false

  # Show the Rails environment being tested at the start of the run.
  config.before(:suite) do
    puts "Running RSpec in the #{Rails.env} environment"
  end
end
