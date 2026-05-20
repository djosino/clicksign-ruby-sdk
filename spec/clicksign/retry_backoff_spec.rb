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
end
