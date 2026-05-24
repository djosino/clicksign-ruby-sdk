# frozen_string_literal: true

RSpec.describe Clicksign::Client do
  include JsonApiFixtures

  subject(:client) do
    described_class.new(api_key: 'test-token', base_url: JsonApiFixtures::BASE_URL)
  end

  let(:path)    { '/envelopes' }
  let(:url)     { "#{JsonApiFixtures::BASE_URL}#{path}" }
  let(:body)    { { 'data' => { 'type' => 'envelopes', 'attributes' => {} } } }
  let(:headers) do
    {
      'Content-Type' => 'application/vnd.api+json',
      'Accept' => 'application/vnd.api+json',
      'Authorization' => 'test-token',
    }
  end

  let(:json_headers) { { 'Content-Type' => 'application/vnd.api+json' } }

  describe '#get' do
    before do
      stub_request(:get, url)
        .to_return(status: 200, body: body.to_json, headers: json_headers)
    end

    it 'sends the correct headers' do
      client.get(path)
      expect(WebMock).to have_requested(:get, url).with(headers: headers)
    end

    it 'returns the parsed response body' do
      expect(client.get(path)).to eq(body)
    end

    it 'encodes query params into the URL' do
      stub_request(:get, url)
        .with(query: { 'filter[status]' => 'draft' })
        .to_return(status: 200, body: body.to_json, headers: json_headers)

      client.get(path, params: { 'filter[status]' => 'draft' })

      expect(WebMock).to have_requested(:get, url)
        .with(query: { 'filter[status]' => 'draft' })
    end

    it 'returns nil for 204 No Content' do
      stub_request(:get, url).to_return(status: 204, body: '')
      expect(client.get(path)).to be_nil
    end
  end

  describe '#post' do
    let(:payload) { { data: { type: 'envelopes', attributes: { name: 'Test' } } } }

    before do
      stub_request(:post, url)
        .to_return(status: 201, body: body.to_json, headers: json_headers)
    end

    it 'sends the correct headers and JSON body' do
      client.post(path, body: payload)
      expect(WebMock).to have_requested(:post, url)
        .with(headers: headers, body: payload.to_json)
    end

    it 'returns the parsed response body' do
      expect(client.post(path, body: payload)).to eq(body)
    end
  end

  describe '#patch' do
    let(:payload) do
      { data: { type: 'envelopes', id: '1', attributes: { name: 'Updated' } } }
    end

    before do
      stub_request(:patch, "#{url}/1")
        .to_return(status: 200, body: body.to_json, headers: json_headers)
    end

    it 'sends the correct headers and JSON body' do
      client.patch("#{path}/1", body: payload)
      expect(WebMock).to have_requested(:patch, "#{url}/1")
        .with(headers: headers, body: payload.to_json)
    end
  end

  describe '#delete' do
    before do
      stub_request(:delete, "#{url}/1").to_return(status: 204, body: '')
    end

    it 'sends DELETE without body by default' do
      client.delete("#{path}/1")
      expect(WebMock).to have_requested(:delete, "#{url}/1").with(headers: headers)
    end

    it 'returns nil on 204' do
      expect(client.delete("#{path}/1")).to be_nil
    end

    context 'with a body (relationship endpoint)' do
      let(:rel_url) { "#{url}/1/relationships/users" }
      let(:rel_body) { { data: [{ type: 'users', id: 'u1' }] } }

      before do
        stub_request(:delete, rel_url).to_return(status: 204, body: '')
      end

      it 'sends the body as JSON' do
        client.delete("#{path}/1/relationships/users", body: rel_body)
        expect(WebMock).to have_requested(:delete, rel_url)
          .with(body: rel_body.to_json)
      end
    end
  end

  describe 'nil api_key behavior' do
    let(:nil_key_client) do
      described_class.new(api_key: nil, base_url: JsonApiFixtures::BASE_URL)
    end

    it 'raises AuthenticationError from the API (no early validation)' do
      stub_request(:get, url)
        .to_return(
          status: 401,
          body: { errors: [{ detail: 'invalid token' }] }.to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )

      expect { nil_key_client.get(path) }.to raise_error(Clicksign::AuthenticationError)
    end
  end

  describe '#get with path containing existing query string' do
    it 'overwrites existing query string — callers must use params hash' do
      url_with_qs = "#{JsonApiFixtures::BASE_URL}#{path}"
      stub_request(:get, url_with_qs)
        .with(query: { 'baz' => 'qux' })
        .to_return(status: 200, body: body.to_json, headers: json_headers)

      # path with existing ?foo=bar — foo=bar is dropped, only params hash survives
      client.get("#{path}?foo=bar", params: { 'baz' => 'qux' })

      expect(WebMock).to have_requested(:get, url_with_qs)
        .with(query: { 'baz' => 'qux' })
    end
  end

  describe 'TimeoutError' do
    it 'raises TimeoutError on Net::OpenTimeout' do
      stub_request(:get, url).to_raise(Net::OpenTimeout)
      expect { client.get(path) }.to raise_error(Clicksign::TimeoutError)
    end

    it 'raises TimeoutError on Net::ReadTimeout' do
      stub_request(:get, url).to_raise(Net::ReadTimeout)
      expect { client.get(path) }.to raise_error(Clicksign::TimeoutError)
    end

    it 'raises TimeoutError on Errno::ECONNREFUSED' do
      stub_request(:get, url).to_raise(Errno::ECONNREFUSED)
      expect { client.get(path) }.to raise_error(Clicksign::TimeoutError)
    end

    it 'raises TimeoutError on Net::WriteTimeout' do
      stub_request(:post, url).to_raise(Net::WriteTimeout)
      expect { client.post(path, body: {}) }.to raise_error(Clicksign::TimeoutError)
    end

    it 'TimeoutError is retryable' do
      expect(Clicksign::TimeoutError.new).to be_retryable
    end
  end

  describe 'retry behavior' do
    let(:error_body) { { errors: [{ detail: 'server error' }] }.to_json }
    let(:retrying_client) do
      described_class.new(api_key: 'test-token', base_url: JsonApiFixtures::BASE_URL,
        max_retries: 2)
    end

    before { allow(retrying_client).to receive(:sleep) }

    it 'retries on 500 and succeeds on third attempt' do
      stub_request(:get, url)
        .to_return(
          { status: 500, body: error_body, headers: json_headers },
          { status: 500, body: error_body, headers: json_headers },
          { status: 200, body: body.to_json, headers: json_headers },
        )

      result = retrying_client.get(path)
      expect(result).to eq(body)
      expect(WebMock).to have_requested(:get, url).times(3)
    end

    it 'raises after exhausting max_retries' do
      stub_request(:get, url)
        .to_return(status: 500, body: error_body, headers: json_headers)

      expect { retrying_client.get(path) }.to raise_error(Clicksign::ServerError)
      expect(WebMock).to have_requested(:get, url).times(3) # 1 + 2 retries
    end

    it 'retries on 429 RateLimitError and succeeds' do
      rate_limit_body = { errors: [{ detail: 'rate limit exceeded' }] }.to_json

      stub_request(:get, url)
        .to_return(
          { status: 429, body: rate_limit_body, headers: json_headers },
          { status: 200, body: body.to_json, headers: json_headers },
        )

      result = retrying_client.get(path)
      expect(result).to eq(body)
      expect(WebMock).to have_requested(:get, url).twice
    end

    it 'does not retry on 422 ValidationError' do
      stub_request(:post, url)
        .to_return(status: 422, body: error_body, headers: json_headers)

      expect { retrying_client.post(path, body: {}) }
        .to raise_error(Clicksign::ValidationError)
      expect(WebMock).to have_requested(:post, url).times(1)
    end

    it 'sleeps with jittered exponential backoff between retries' do
      stub_request(:get, url)
        .to_return(
          { status: 500, body: error_body, headers: json_headers },
          { status: 200, body: body.to_json, headers: json_headers },
        )

      slept = []
      allow(retrying_client).to receive(:sleep) { |duration| slept << duration }

      retrying_client.get(path)

      expect(slept.size).to eq(1)
      expect(slept.first).to be >= 0
      expect(slept.first).to be < Clicksign::RetryBackoff.ceiling(1)
    end

    it 'uses RetryBackoff.delay for the sleep duration' do
      stub_request(:get, url)
        .to_return(
          { status: 500, body: error_body, headers: json_headers },
          { status: 200, body: body.to_json, headers: json_headers },
        )
      allow(Clicksign::RetryBackoff).to receive(:delay).with(1).and_return(0.5)

      retrying_client.get(path)

      expect(retrying_client).to have_received(:sleep).with(0.5).once
    end
  end
end
