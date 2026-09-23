source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.4.10"

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 8.0.2.1'

# Use sqlite3 as the database for Active Record
gem 'sqlite3', '~> 2.1'

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 8.0"

gem 'jwt'

gem 'simple_command'

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# Must be >= 2.12: older versions require active_support/basic_object and
# active_support/proxy_object, which were removed in ActiveSupport 8.0 (Rails 8)
gem 'jbuilder', '~> 2.12'

# Need to lock json to 2.x to be compatible with Rails 8.0.2's ActiveSupport
gem 'json', '~> 2'

# Use Redis adapter to run Action Cable in production
# gem "redis", "~> 4.0"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
gem "rack-cors"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]
  gem 'solargraph', '~> 0.60.0'
  # RSpec for writing and running the test suite (see TESTING.md)
  gem 'rspec-rails', '~> 7.0'
  # FactoryBot for building test data cleanly (see spec/factories)
  gem 'factory_bot_rails'
  # Code coverage for the RSpec suite (see spec/spec_helper.rb and TESTING.md)
  gem 'simplecov', require: false
end

group :development do
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
end

