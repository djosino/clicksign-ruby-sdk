# frozen_string_literal: true

RSpec.describe Clicksign::Services do
  subject(:service) do
    described_class.new(api_key: 'service-token', base_url: JsonApiFixtures::BASE_URL)
  end

  include_context 'with clicksign configured'

  let(:list_url) { "#{JsonApiFixtures::BASE_URL}/envelopes" }
  let(:json_headers) { { 'Content-Type' => 'application/vnd.api+json' } }
  let(:empty_list) { { 'data' => [] }.to_json }

  describe '#use' do
    before do
      stub_request(:get, list_url)
        .to_return(status: 200, body: empty_list, headers: json_headers)
    end

    it 'routes resource calls through the service client' do
      service.use { Clicksign::Resources::Notarial::Envelope.list }
      expect(WebMock).to have_requested(:get, list_url)
        .with(headers: { 'Authorization' => 'service-token' })
    end

    it 'does not use the global client inside the block' do
      service.use { Clicksign::Resources::Notarial::Envelope.list }
      expect(WebMock).not_to have_requested(:get, list_url)
        .with(headers: { 'Authorization' => 'test-token' })
    end

    it 'restores nil client after the block' do
      service.use {}
      expect(Thread.current[:clicksign_client]).to be_nil
    end

    it 'restores nil client even when the block raises' do
      expect { service.use { raise 'boom' } }.to raise_error('boom')
      expect(Thread.current[:clicksign_client]).to be_nil
    end

    context 'when nested' do
      let(:inner_service) do
        described_class.new(api_key: 'inner-token', base_url: JsonApiFixtures::BASE_URL)
      end

      it 'restores the outer client after the inner block exits' do
        outer_client = nil
        inner_client = nil

        service.use do
          outer_client = Thread.current[:clicksign_client]
          inner_service.use do
            inner_client = Thread.current[:clicksign_client]
          end
          expect(Thread.current[:clicksign_client]).to eq(outer_client)
        end

        expect(inner_client).not_to eq(outer_client)
        expect(Thread.current[:clicksign_client]).to be_nil
      end
    end
  end

  describe '#initialize' do
    context 'with environment:' do
      it 'raises ArgumentError for unknown environment' do
        expect { described_class.new(api_key: 'tok', environment: :staging) }
          .to raise_error(ArgumentError, /Unknown environment: staging/)
      end

      it 'accepts :sandbox' do
        expect { described_class.new(api_key: 'tok', environment: :sandbox) }
          .not_to raise_error
      end

      it 'accepts :production' do
        expect { described_class.new(api_key: 'tok', environment: :production) }
          .not_to raise_error
      end
    end

    context 'with base_url:' do
      it 'overrides the environment URL' do
        expect { described_class.new(api_key: 'tok', base_url: 'https://custom.example.com/api/v3') }
          .not_to raise_error
      end
    end
  end
end
