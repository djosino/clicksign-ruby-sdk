# frozen_string_literal: true

RSpec.describe Clicksign::RetryBackoff do
  describe '.ceiling' do
    it 'returns exponential base delay for early attempts' do
      expect(described_class.ceiling(1)).to eq(0.5)
      expect(described_class.ceiling(2)).to eq(1.0)
      expect(described_class.ceiling(3)).to eq(2.0)
      expect(described_class.ceiling(4)).to eq(4.0)
    end

    it 'caps delay at 30 seconds' do
      expect(described_class.ceiling(10)).to eq(30.0)
      expect(described_class.ceiling(20)).to eq(30.0)
    end
  end

  describe '.delay' do
    let(:rng) { instance_double(Random) }

    it 'returns a value in [0, ceiling) using the given rng' do
      allow(rng).to receive(:rand).with(0.5).and_return(0.25)

      expect(described_class.delay(1, rng: rng)).to eq(0.25)
    end

    it 'uses ceiling for the attempt when calling rand' do
      allow(rng).to receive(:rand).with(2.0).and_return(1.5)

      expect(described_class.delay(3, rng: rng)).to eq(1.5)
    end

    it 'returns 0.0 when ceiling is zero' do
      allow(described_class).to receive(:ceiling).with(1).and_return(0.0)

      expect(described_class.delay(1, rng: rng)).to eq(0.0)
    end

    it 'spreads delays below the ceiling (full jitter)' do
      ceiling = described_class.ceiling(1)
      delays = 50.times.map { |i| described_class.delay(1, rng: Random.new(i + 1)) }

      expect(delays).to all(be >= 0)
      expect(delays).to all(be < ceiling)
      expect(delays.uniq.size).to be > 1
    end
  end

  describe '.parse_retry_after' do
    it 'parses a numeric seconds value' do
      expect(described_class.parse_retry_after('Retry-After' => '3')).to eq(3.0)
      expect(described_class.parse_retry_after('Retry-After' => '1.5')).to eq(1.5)
    end

    it 'is case-insensitive on the header name' do
      expect(described_class.parse_retry_after('retry-after' => '2')).to eq(2.0)
    end

    it 'returns nil for missing header' do
      expect(described_class.parse_retry_after({})).to be_nil
      expect(described_class.parse_retry_after(nil)).to be_nil
    end

    it 'returns nil for blank value' do
      expect(described_class.parse_retry_after('Retry-After' => '')).to be_nil
      expect(described_class.parse_retry_after('Retry-After' => '  ')).to be_nil
    end

    it 'returns nil for non-numeric value' do
      expect(described_class.parse_retry_after('Retry-After' => 'tomorrow')).to be_nil
    end
  end

  describe '.retry_delay' do
    let(:rng) { instance_double(Random) }

    before { allow(rng).to receive(:rand).with(0.5).and_return(0.3) }

    it 'returns jitter when no Retry-After header' do
      expect(described_class.retry_delay(1, nil, rng: rng)).to eq(0.3)
      expect(described_class.retry_delay(1, {}, rng: rng)).to eq(0.3)
    end

    it 'returns Retry-After when it exceeds jitter' do
      headers = { 'Retry-After' => '5' }
      expect(described_class.retry_delay(1, headers, rng: rng)).to eq(5.0)
    end

    it 'returns jitter when it exceeds Retry-After' do
      headers = { 'Retry-After' => '0.1' }
      expect(described_class.retry_delay(1, headers, rng: rng)).to eq(0.3)
    end
  end
end
