ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
# Bootsnap's ISeq cache calls RubyVM::InstructionSequence#to_binary, which
# raises "should not compile with coverage" on Ruby 3.4 while a coverage tool
# is active. SimpleCov is started in spec/spec_helper.rb (loaded first via the
# --require spec_helper option in .rspec), so skip bootsnap only when running
# instrumented test runs; normal boots are unaffected.
require "bootsnap/setup" unless defined?(SimpleCov) # Speed up boot time by caching expensive operations.
