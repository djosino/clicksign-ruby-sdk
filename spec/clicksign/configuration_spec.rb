# frozen_string_literal: true

RSpec.describe Clicksign::Configuration do
  subject(:config) { described_class.new }

  describe 'defaults' do
    it 'sets base_url to production' do
      expect(config.base_url).to eq('https://app.clicksign.com/api/v3')
    end

    it 'leaves api_key nil' do
      expect(config.api_key).to be_nil
    end

    it 'sets open_timeout to 2' do
      expect(config.open_timeout).to eq(2)
    end

    it 'sets read_timeout to 10' do
      expect(config.read_timeout).to eq(10)
    end

    it 'sets write_timeout to 10' do
      expect(config.write_timeout).to eq(10)
    end

    it 'sets max_retries to 0' do
      expect(config.max_retries).to eq(0)
    end

    it 'leaves logger nil' do
      expect(config.logger).to be_nil
    end
  end

  describe 'setters' do
    it 'accepts api_key' do
      config.api_key = 'my-token'
      expect(config.api_key).to eq('my-token')
    end

    it 'accepts base_url override' do
      config.base_url = 'https://sandbox.clicksign.com/api/v3'
      expect(config.base_url).to eq('https://sandbox.clicksign.com/api/v3')
    end

    it 'accepts timeout overrides', :aggregate_failures do
      config.open_timeout  = 5
      config.read_timeout  = 30
      config.write_timeout = 30
      expect(config.open_timeout).to eq(5)
      expect(config.read_timeout).to eq(30)
      expect(config.write_timeout).to eq(30)
    end

    it 'accepts max_retries' do
      config.max_retries = 3
      expect(config.max_retries).to eq(3)
    end

    it 'accepts a logger' do
      logger = double('Logger', warn: nil)
      config.logger = logger
      expect(config.logger).to be(logger)
    end
  end

  describe '#environment=' do
    it 'sets base_url to sandbox URL' do
      config.environment = :sandbox
      expect(config.base_url).to eq('https://sandbox.clicksign.com/api/v3')
    end

    it 'sets base_url to production URL' do
      config.environment = :production
      expect(config.base_url).to eq('https://app.clicksign.com/api/v3')
    end

    it 'accepts string values' do
      config.environment = 'sandbox'
      expect(config.base_url).to eq('https://sandbox.clicksign.com/api/v3')
    end

    it 'raises ArgumentError for unknown environment' do
      expect { config.environment = :staging }
        .to raise_error(ArgumentError, /Unknown environment: staging/)
    end
  end
end

RSpec.describe Clicksign do
  describe '.configure' do
    it 'yields the configuration object' do
      described_class.configure do |c|
        c.api_key  = 'tok'
        c.base_url = 'https://sandbox.clicksign.com/api/v3'
      end

      expect(described_class.configuration.api_key).to eq('tok')
      expect(described_class.configuration.base_url).to eq('https://sandbox.clicksign.com/api/v3')
    end

    it 'persists configuration across calls' do
      described_class.configure { |c| c.api_key = 'persistent' }
      expect(described_class.configuration.api_key).to eq('persistent')
    end

    it 'supports environment shortcut' do
      described_class.configure { |c| c.environment = :sandbox }
      expect(described_class.configuration.base_url)
        .to eq('https://sandbox.clicksign.com/api/v3')
    end
  end

  describe '.reset!' do
    it 'clears configuration so next access returns a new instance' do
      described_class.configure { |c| c.api_key = 'old' }
      described_class.reset!
      expect(described_class.configuration.api_key).to be_nil
    end
  end
end
