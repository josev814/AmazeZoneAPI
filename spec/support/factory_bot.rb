# Enables the FactoryBot shorthand (create(:user), build(:product), etc.)
# inside examples. factory_bot_rails is loaded automatically by Rails; this
# file just opts the RSpec examples into the syntax.
require "factory_bot_rails"

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
