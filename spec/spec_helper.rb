# frozen_string_literal: true

require 'webmock/rspec'
require 'clicksign'

Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |file| require file }

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.before do
    Clicksign.reset!
  end
end
