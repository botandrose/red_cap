require "simplecov"
require "simplecov_json_formatter"

SimpleCov.start do
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter
  ])
  add_filter "/spec/"
  add_filter "/bin/"
  add_filter "/pkg/"

  add_group "Core", "lib/red_cap.rb"
  add_group "Client", "lib/red_cap/client.rb"
  add_group "Forms", ["lib/red_cap/form.rb", "lib/red_cap/form/"]
  add_group "Cache", "lib/red_cap/cache.rb"
  add_group "Other", "lib/red_cap/"

  minimum_coverage 90
  minimum_coverage_by_file 80
end

require "bundler/setup"
require "active_support/all"
require "red_cap"
require "digest"
require "fileutils"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
