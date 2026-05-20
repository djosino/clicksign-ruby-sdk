# frozen_string_literal: true

RSpec.describe Clicksign::Instrumentation do
  after { described_class.clear }

  describe '.on / .publish' do
    it 'calls a registered callback with the payload' do
      received = nil
      described_class.on(:request) { |e| received = e }
      described_class.publish(:request, { method: :get, path: '/test' })
      expect(received).to eq({ method: :get, path: '/test' })
    end

    it 'supports multiple callbacks for the same event' do
      calls = []
      described_class.on(:request) { |_| calls << 1 }
      described_class.on(:request) { |_| calls << 2 }
      described_class.publish(:request, {})
      expect(calls).to eq([1, 2])
    end

    it 'raises ArgumentError for unknown events' do
      expect { described_class.on(:unknown) {} }
        .to raise_error(ArgumentError, /Unknown event/)
    end

    it 'does not raise when no callbacks are registered' do
      expect { described_class.publish(:request, {}) }.not_to raise_error
    end

    it 'isolates callback exceptions so they do not propagate' do
      described_class.on(:request) { raise 'callback error' }
      expect { described_class.publish(:request, {}) }.not_to raise_error
    end

    it 'continues calling remaining callbacks after one raises' do
      second_called = false
      described_class.on(:request) { raise 'first callback error' }
      described_class.on(:request) { second_called = true }
      described_class.publish(:request, {})
      expect(second_called).to be(true)
    end

    context 'when config.logger is set' do
      let(:logger) { double('Logger', warn: nil) }

      before do
        Clicksign.configure do |c|
          c.api_key  = 'tok'
          c.base_url = JsonApiFixtures::BASE_URL
          c.logger   = logger
        end
      end

      it 'logs callback errors via logger.warn' do
        described_class.on(:request) { raise 'boom' }
        described_class.publish(:request, {})

        expect(logger).to have_received(:warn)
          .with(a_string_matching(/instrumentation callback error.*request.*boom/))
      end
    end

    context 'when config.logger is nil (default)' do
      it 'silently ignores callback errors' do
        described_class.on(:request) { raise 'silent error' }
        expect { described_class.publish(:request, {}) }.not_to raise_error
      end
    end
  end

  describe '.clear' do
    it 'removes all registered callbacks' do
      called = false
      described_class.on(:request) { called = true }
      described_class.clear
      described_class.publish(:request, {})
      expect(called).to be(false)
    end
  end
end

RSpec.describe 'Clicksign instrumentation integration' do
  include JsonApiFixtures

  subject(:client) do
    Clicksign::Client.new(api_key: 'test-token', base_url: JsonApiFixtures::BASE_URL)
  end

  let(:path)         { '/envelopes' }
  let(:url)          { "#{JsonApiFixtures::BASE_URL}#{path}" }
  let(:body)         { { 'data' => { 'type' => 'envelopes', 'attributes' => {} } } }
  let(:json_headers) { { 'Content-Type' => 'application/vnd.api+json' } }
  let(:error_body)   { { errors: [{ detail: 'server error' }] }.to_json }

  after { Clicksign::Instrumentation.clear }

  describe ':request event' do
    it 'is published on a successful request' do
      stub_request(:get, url).to_return(status: 200, body: body.to_json,
                                        headers: json_headers)
      events = []
      Clicksign::Instrumentation.on(:request) { |e| events << e }

      client.get(path)

      expect(events.size).to eq(1)
      expect(events.first).to include(method: :get, path: path, status: 200, attempt: 1)
      expect(events.first[:duration_ms]).to be_a(Float)
    end

    it 'is published even when the request raises an error' do
      stub_request(:get, url)
        .to_return(status: 404, body: { errors: [{ detail: 'not found' }] }.to_json,
                   headers: json_headers)
      events = []
      Clicksign::Instrumentation.on(:request) { |e| events << e }

      expect { client.get(path) }.to raise_error(Clicksign::NotFoundError)
      expect(events.first).to include(status: 404)
    end
  end

  describe ':error event' do
    it 'is published with the raised exception on HTTP error' do
      stub_request(:get, url)
        .to_return(status: 404, body: { errors: [{ detail: 'not found' }] }.to_json,
                   headers: json_headers)
      errors = []
      Clicksign::Instrumentation.on(:error) { |e| errors << e }

      expect { client.get(path) }.to raise_error(Clicksign::NotFoundError)
      expect(errors.size).to eq(1)
      expect(errors.first[:error]).to be_a(Clicksign::NotFoundError)
      expect(errors.first).to include(method: :get, path: path, status: 404)
    end

    it 'is published on timeout' do
      stub_request(:get, url).to_raise(Net::ReadTimeout)
      errors = []
      Clicksign::Instrumentation.on(:error) { |e| errors << e }

      expect { client.get(path) }.to raise_error(Clicksign::TimeoutError)
      expect(errors.first[:error]).to be_a(Clicksign::TimeoutError)
      expect(errors.first[:status]).to be_nil
    end
  end

  describe ':retry event' do
    let(:retrying_client) do
      Clicksign::Client.new(api_key: 'test-token', base_url: JsonApiFixtures::BASE_URL,
                            max_retries: 1)
    end

    before { allow(retrying_client).to receive(:sleep) }

    it 'is published before each retry with backoff metadata' do
      stub_request(:get, url)
        .to_return({ status: 500, body: error_body, headers: json_headers },
                   { status: 200, body: body.to_json, headers: json_headers })
      retries = []
      Clicksign::Instrumentation.on(:retry) { |e| retries << e }

      retrying_client.get(path)

      expect(retries.size).to eq(1)
      expect(retries.first).to include(
        method: :get, path: path, attempt: 1, max_retries: 1, wait_ms: 500,
      )
      expect(retries.first[:error]).to be_a(Clicksign::ServerError)
    end

    it 'publishes one request event per attempt' do
      stub_request(:get, url)
        .to_return({ status: 500, body: error_body, headers: json_headers },
                   { status: 200, body: body.to_json, headers: json_headers })
      request_events = []
      Clicksign::Instrumentation.on(:request) { |e| request_events << e }

      retrying_client.get(path)

      expect(request_events.map { |e| e[:attempt] }).to eq([1, 2])
      expect(request_events.map { |e| e[:status] }).to eq([500, 200])
    end
  end

  describe 'Clicksign.on_request / on_retry / on_error' do
    before do
      Clicksign.configure do |c|
        c.api_key = 'tok'
        c.base_url = JsonApiFixtures::BASE_URL
      end
    end

    it 'registers callbacks via the top-level helpers' do
      stub_request(:get, url).to_return(status: 200, body: body.to_json,
                                        headers: json_headers)
      received = nil
      Clicksign.on_request { |e| received = e }

      client.get(path)
      expect(received).to include(method: :get, status: 200)
    end

    it 'on_retry fires when the client retries a failed request' do
      retrying_client = Clicksign::Client.new(
        api_key: 'tok',
        base_url: JsonApiFixtures::BASE_URL,
        max_retries: 1,
      )
      allow(retrying_client).to receive(:sleep)

      stub_request(:get, url)
        .to_return(
          { status: 500, body: error_body, headers: json_headers },
          { status: 200, body: body.to_json, headers: json_headers },
        )

      retry_events = []
      Clicksign.on_retry { |e| retry_events << e }

      retrying_client.get(path)
      expect(retry_events.length).to eq(1)
      expect(retry_events.first).to include(attempt: 1)
    end

    it 'on_error fires when the request raises an error' do
      stub_request(:get, url)
        .to_return(status: 500, body: error_body, headers: json_headers)

      error_events = []
      Clicksign.on_error { |e| error_events << e }

      expect { client.get(path) }.to raise_error(Clicksign::ServerError)
      expect(error_events.length).to eq(1)
      expect(error_events.first).to include(method: :get, status: 500)
    end
  end
end
