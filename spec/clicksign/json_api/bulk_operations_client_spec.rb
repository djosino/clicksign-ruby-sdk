# frozen_string_literal: true

RSpec.describe Clicksign::JsonApi::BulkOperationsClient do
  include JsonApiFixtures

  subject(:client) do
    described_class.new(
      api_key: 'test-token',
      base_url: JsonApiFixtures::BASE_URL,
    )
  end

  let(:path) { '/envelopes/env-id/bulk_requirements' }
  let(:body) do
    {
      'atomic:operations' => [
        {
          'op' => 'add',
          'data' => {
            'type' => 'requirements',
            'attributes' => { 'action' => 'agree', 'role' => 'sign' },
            'relationships' => {
              'signer' => { 'data' => { 'type' => 'signers', 'id' => 'signer-id' } },
              'document' => { 'data' => { 'type' => 'documents',
                                          'id' => 'document-id' } },
            },
          },
        },
      ],
    }
  end
  let(:url) { "#{JsonApiFixtures::BASE_URL}#{path}" }

  describe '#post' do
    before do
      stub_request(:post, url)
        .to_return(
          status: status,
          body: response_body.to_json,
          headers: { 'Content-Type' => 'application/json' },
        )
    end

    context 'when response has atomic:results' do
      let(:status) { 404 }
      let(:response_body) do
        { 'atomic:results' => [{ 'errors' => [{ 'detail' => 'not found' }] }] }
      end

      it 'returns parsed body without raising' do
        expect(client.post(path, body: body)).to eq(response_body)
      end

      it 'sends JSON:API headers and authorization' do
        client.post(path, body: body)

        expect(WebMock).to have_requested(:post, url)
          .with(
            headers: {
              'Content-Type' => 'application/vnd.api+json',
              'Accept' => 'application/vnd.api+json',
              'Authorization' => 'test-token',
            },
            body: body.to_json,
          )
      end
    end

    context 'when response is successful' do
      let(:status) { 200 }
      let(:response_body) do
        { 'atomic:results' => [{ 'data' => {} }] }
      end

      it 'returns parsed body' do
        expect(client.post(path, body: body)).to eq(response_body)
      end
    end

    context 'when response has top-level errors only' do
      let(:status) { 422 }
      let(:response_body) do
        { 'errors' => [{ 'detail' => 'envelope invalid' }] }
      end

      it 'raises ValidationError' do
        expect { client.post(path, body: body) }
          .to raise_error(Clicksign::ValidationError, 'envelope invalid')
      end
    end

    context 'when response is an unhandled error' do
      let(:status) { 500 }
      let(:response_body) do
        { 'errors' => [{ 'detail' => 'server error' }] }
      end

      it 'raises ServerError' do
        expect { client.post(path, body: body) }
          .to raise_error(Clicksign::ServerError)
      end
    end

    context 'when response is unauthorized' do
      let(:status) { 401 }
      let(:response_body) do
        { 'errors' => [{ 'detail' => 'Access Token inválido' }] }
      end

      it 'raises AuthenticationError' do
        expect { client.post(path, body: body) }
          .to raise_error(Clicksign::AuthenticationError)
      end
    end

    context 'when response has no atomic:results and status is forbidden' do
      let(:status) { 403 }
      let(:response_body) do
        { 'errors' => [{ 'detail' => 'forbidden' }] }
      end

      it 'raises AuthenticationError' do
        expect { client.post(path, body: body) }
          .to raise_error(Clicksign::AuthenticationError, 'forbidden')
      end
    end

    context 'when response body is not valid JSON' do
      let(:status) { 200 }
      let(:response_body) { nil }

      before do
        stub_request(:post, url)
          .to_return(status: 200, body: 'not-json', headers: {})
      end

      it 'does not raise JSON::ParserError' do
        expect { client.post(path, body: body) }.not_to raise_error
      end
    end
  end

  describe 'timeout and retry behavior' do
    let(:retrying_client) do
      described_class.new(
        api_key: 'test-token',
        base_url: JsonApiFixtures::BASE_URL,
        max_retries: 2,
      )
    end

    before { allow(retrying_client).to receive(:sleep) }

    it 'raises TimeoutError on Net::OpenTimeout' do
      stub_request(:post, url).to_raise(Net::OpenTimeout)
      expect { retrying_client.post(path, body: body) }
        .to raise_error(Clicksign::TimeoutError)
    end

    it 'raises TimeoutError on Net::ReadTimeout' do
      stub_request(:post, url).to_raise(Net::ReadTimeout)
      expect { retrying_client.post(path, body: body) }
        .to raise_error(Clicksign::TimeoutError)
    end

    it 'retries on timeout and succeeds on subsequent attempt' do
      success_body = { 'atomic:results' => [{ 'data' => {} }] }
      stub_request(:post, url)
        .to_raise(Net::ReadTimeout)
        .to_return(status: 200, body: success_body.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      result = retrying_client.post(path, body: body)
      expect(result).to eq(success_body)
      expect(WebMock).to have_requested(:post, url).twice
    end

    it 'does not retry on ServerError (500) — only timeouts are retried' do
      error_body = { 'errors' => [{ 'detail' => 'server error' }] }.to_json

      stub_request(:post, url)
        .to_return(status: 500, body: error_body,
                   headers: { 'Content-Type' => 'application/json' })

      expect { retrying_client.post(path, body: body) }
        .to raise_error(Clicksign::ServerError)
      expect(WebMock).to have_requested(:post, url).once
    end

    it 'raises after exhausting max_retries' do
      stub_request(:post, url).to_raise(Net::ReadTimeout)
      expect { retrying_client.post(path, body: body) }
        .to raise_error(Clicksign::TimeoutError)
      expect(WebMock).to have_requested(:post, url).times(3)
    end

    it 'sleeps with jittered exponential backoff between retries' do
      stub_request(:post, url).to_raise(Net::ReadTimeout)
      slept = []
      allow(retrying_client).to receive(:sleep) { |duration| slept << duration }

      expect { retrying_client.post(path, body: body) }.to raise_error(Clicksign::TimeoutError)

      expect(slept.size).to eq(2)
      expect(slept[0]).to be >= 0
      expect(slept[0]).to be < Clicksign::RetryBackoff.ceiling(1)
      expect(slept[1]).to be >= 0
      expect(slept[1]).to be < Clicksign::RetryBackoff.ceiling(2)
    end

    it 'uses RetryBackoff.delay for the sleep duration' do
      stub_request(:post, url).to_raise(Net::ReadTimeout)
      allow(Clicksign::RetryBackoff).to receive(:delay).with(1).and_return(0.5)
      allow(Clicksign::RetryBackoff).to receive(:delay).with(2).and_return(1.0)

      expect { retrying_client.post(path, body: body) }.to raise_error(Clicksign::TimeoutError)

      expect(retrying_client).to have_received(:sleep).with(0.5).once
      expect(retrying_client).to have_received(:sleep).with(1.0).once
    end
  end
end

RSpec.describe Clicksign do
  include JsonApiFixtures

  describe '.bulk_operations_client' do
    before do
      described_class.configure do |c|
        c.api_key  = 'configured-token'
        c.base_url = JsonApiFixtures::BASE_URL
      end
    end

    it 'returns a BulkOperationsClient using configuration' do
      client = described_class.bulk_operations_client

      expect(client).to be_a(Clicksign::JsonApi::BulkOperationsClient)
    end

    it 'reuses the same instance' do
      first = described_class.bulk_operations_client
      second = described_class.bulk_operations_client

      expect(second).to equal(first)
    end

    it 'resets the client when reset! is called' do
      first = described_class.bulk_operations_client
      described_class.reset!
      second = described_class.bulk_operations_client

      expect(second).not_to equal(first)
    end
  end
end
