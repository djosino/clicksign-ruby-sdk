# frozen_string_literal: true

RSpec.describe Clicksign::JsonApi::Parser do
  describe '.parse' do
    context 'when data is a single object (Hash)' do
      let(:raw) do
        {
          'data' => {
            'id' => '1',
            'type' => 'envelopes',
            'attributes' => { 'name' => 'Contract' },
            'relationships' => { 'folder' => { 'data' => { 'id' => '2' } } },
          },
        }
      end

      it 'returns data as a one-element array', :aggregate_failures do
        result = described_class.parse(raw)

        expect(result[:data]).to be_an(Array)
        expect(result[:data].size).to eq(1)
        expect(result[:data].first['id']).to eq('1')
        expect(result[:data].first['attributes']['name']).to eq('Contract')
      end
    end

    context 'when data is a collection (Array)' do
      let(:raw) do
        {
          'data' => [
            { 'id' => '1', 'type' => 'envelopes', 'attributes' => { 'name' => 'A' },
              'relationships' => {} },
            { 'id' => '2', 'type' => 'envelopes', 'attributes' => { 'name' => 'B' },
              'relationships' => {} },
          ],
        }
      end

      it 'returns all items', :aggregate_failures do
        result = described_class.parse(raw)

        expect(result[:data].size).to eq(2)
        expect(result[:data].map { |d| d['id'] }).to eq(%w[1 2])
      end
    end

    context 'when data is nil (empty response body parsed as hash)' do
      it 'returns an empty data array' do
        result = described_class.parse({ 'data' => nil })

        expect(result[:data]).to eq([])
      end
    end

    context 'when the response has included resources' do
      let(:raw) do
        {
          'data' => { 'id' => '1', 'type' => 'signers', 'attributes' => {},
                      'relationships' => {} },
          'included' => [
            { 'id' => '10', 'type' => 'envelopes', 'attributes' => { 'name' => 'Env' },
              'relationships' => {} },
          ],
        }
      end

      it 'parses included resources', :aggregate_failures do
        result = described_class.parse(raw)

        expect(result[:included].size).to eq(1)
        expect(result[:included].first['type']).to eq('envelopes')
        expect(result[:included].first['id']).to eq('10')
      end
    end

    context 'when included contains malformed entries without type' do
      let(:raw) do
        {
          'data' => { 'id' => '1', 'type' => 'envelopes', 'attributes' => {},
                      'relationships' => {} },
          'included' => [
            {},
            { 'id' => '10', 'type' => 'signers', 'attributes' => {},
              'relationships' => {} },
          ],
        }
      end

      it 'filters out entries without type' do
        result = described_class.parse(raw)

        expect(result[:included].size).to eq(1)
        expect(result[:included].first['type']).to eq('signers')
      end
    end

    context 'when attributes or relationships are absent' do
      it 'defaults to empty hash for missing attributes and relationships' do
        raw = { 'data' => { 'id' => '1', 'type' => 'events' } }
        result = described_class.parse(raw)

        expect(result[:data].first['attributes']).to eq({})
        expect(result[:data].first['relationships']).to eq({})
      end
    end

    context 'when included is absent' do
      it 'returns an empty included array' do
        raw = { 'data' => [] }
        result = described_class.parse(raw)

        expect(result[:included]).to eq([])
      end
    end

    context 'when links are present' do
      it 'exposes links for pagination' do
        raw = {
          'data' => [],
          'links' => { 'next' => 'https://api.example.com/widgets?page[number]=2' },
        }
        result = described_class.parse(raw)

        expect(result[:links]).to eq(raw['links'])
      end

      it 'sets links to nil when the key is absent' do
        result = described_class.parse({ 'data' => [] })

        expect(result[:links]).to be_nil
      end
    end
  end
end
