# frozen_string_literal: true

RSpec.describe Clicksign::ErrorHandler do
  def mock_response(code, body = nil, headers: {})
    response = instance_double(Net::HTTPResponse)
    allow(response).to receive_messages(
      code: code.to_s,
      message: 'HTTP Error',
      body: body,
    )
    allow(response).to receive(:[]) { |key| headers[key.downcase] }
    allow(response).to receive(:each_header).and_return(headers.each)
    response
  end

  def json_body(*details)
    { 'errors' => details.map { |d| { 'detail' => d } } }.to_json
  end

  describe '.call' do
    context 'with 2xx responses' do
      it 'returns nil for 200' do
        expect(described_class.call(mock_response(200))).to be_nil
      end

      it 'returns nil for 201' do
        expect(described_class.call(mock_response(201))).to be_nil
      end

      it 'returns nil for 204' do
        expect(described_class.call(mock_response(204))).to be_nil
      end
    end

    context 'with 401 Unauthorized' do
      it 'raises AuthenticationError with the error detail' do
        expect do
          described_class.call(mock_response(401, json_body('invalid token')))
        end.to raise_error(Clicksign::AuthenticationError, 'invalid token')
      end
    end

    context 'with 403 Forbidden' do
      it 'raises AuthenticationError' do
        expect do
          described_class.call(mock_response(403, json_body('forbidden')))
        end.to raise_error(Clicksign::AuthenticationError, 'forbidden')
      end
    end

    context 'with 404 Not Found' do
      it 'raises NotFoundError' do
        expect do
          described_class.call(mock_response(404, json_body('not found')))
        end.to raise_error(Clicksign::NotFoundError, 'not found')
      end
    end

    context 'with 400 Bad Request' do
      it 'raises ValidationError' do
        expect do
          described_class.call(mock_response(400, json_body('name is blank')))
        end.to raise_error(Clicksign::ValidationError, 'name is blank')
      end
    end

    context 'with 422 Unprocessable Entity' do
      it 'raises ValidationError with the error detail' do
        expect do
          described_class.call(mock_response(422, json_body('email is invalid')))
        end.to raise_error(Clicksign::ValidationError, 'email is invalid')
      end

      it 'joins multiple error details' do
        body = { 'errors' => [{ 'detail' => 'name blank' },
                              { 'detail' => 'email invalid' }] }.to_json
        expect do
          described_class.call(mock_response(422, body))
        end.to raise_error(Clicksign::ValidationError, 'name blank, email invalid')
      end
    end

    context 'with 409 Conflict' do
      it 'raises ConflictError' do
        expect do
          described_class.call(mock_response(409, json_body('conflict')))
        end.to raise_error(Clicksign::ConflictError, 'conflict')
      end
    end

    context 'with 429 Too Many Requests' do
      it 'raises RateLimitError' do
        expect do
          described_class.call(mock_response(429, json_body('rate limit exceeded')))
        end.to raise_error(Clicksign::RateLimitError, 'rate limit exceeded')
      end
    end

    context 'with 500 Internal Server Error' do
      it 'raises ServerError' do
        expect do
          described_class.call(mock_response(500, json_body('internal error')))
        end.to raise_error(Clicksign::ServerError, 'internal error')
      end
    end

    context 'with 503 Service Unavailable' do
      it 'raises ServerError' do
        expect do
          described_class.call(mock_response(503, json_body('unavailable')))
        end.to raise_error(Clicksign::ServerError, 'unavailable')
      end
    end

    context 'when response body is nil' do
      it 'falls back to response.message without raising TypeError' do
        expect do
          described_class.call(mock_response(500, nil))
        end.to raise_error(Clicksign::ServerError, 'HTTP Error')
      end
    end

    context 'when response body is empty' do
      it 'falls back to response.message' do
        expect do
          described_class.call(mock_response(500, ''))
        end.to raise_error(Clicksign::ServerError, 'HTTP Error')
      end
    end

    context 'when response body is not JSON' do
      it 'falls back to response.message' do
        expect do
          described_class.call(mock_response(500, 'Internal Server Error'))
        end.to raise_error(Clicksign::ServerError, 'HTTP Error')
      end
    end

    context 'when response body is a JSON array (not a Hash)' do
      it 'falls back to response.message without raising TypeError' do
        expect do
          described_class.call(mock_response(422, '[{"detail":"error"}]'))
        end.to raise_error(Clicksign::ValidationError, 'HTTP Error')
      end
    end

    context 'when errors body has title instead of detail' do
      it 'uses title as fallback' do
        body = { 'errors' => [{ 'title' => 'Bad Request' }] }.to_json
        expect do
          described_class.call(mock_response(400, body))
        end.to raise_error(Clicksign::ValidationError, 'Bad Request')
      end
    end

    context 'when raising errors with metadata' do
      it 'exposes status_code on the raised exception' do
        err = nil
        begin
          described_class.call(mock_response(404, json_body('not found')))
        rescue Clicksign::NotFoundError => e
          err = e
        end
        expect(err.status_code).to eq(404)
      end

      it 'exposes request_id when x-request-id header is present' do
        err = nil
        begin
          described_class.call(
            mock_response(422, json_body('invalid'),
                          headers: { 'x-request-id' => 'req-abc123' }),
          )
        rescue Clicksign::ValidationError => e
          err = e
        end
        expect(err.request_id).to eq('req-abc123')
      end

      it 'exposes response_body on the raised exception' do
        body = json_body('server error')
        err = nil
        begin
          described_class.call(mock_response(500, body))
        rescue Clicksign::ServerError => e
          err = e
        end
        expect(err.response_body).to eq(body)
      end
    end

    context 'when checking retryable?' do
      it 'is true for RateLimitError' do
        err = nil
        begin
          described_class.call(mock_response(429, json_body('rate limited')))
        rescue Clicksign::RateLimitError => e
          err = e
        end
        expect(err).to be_retryable
      end

      it 'is true for ServerError' do
        err = nil
        begin
          described_class.call(mock_response(500, json_body('server error')))
        rescue Clicksign::ServerError => e
          err = e
        end
        expect(err).to be_retryable
      end

      it 'is false for ValidationError' do
        err = nil
        begin
          described_class.call(mock_response(422, json_body('invalid')))
        rescue Clicksign::ValidationError => e
          err = e
        end
        expect(err).not_to be_retryable
      end
    end

    context 'with RateLimitError rate limit headers' do
      it 'exposes rate_limit_remaining and rate_limit_reset' do
        err = nil
        begin
          described_class.call(
            mock_response(429, json_body('rate limited'), headers: {
                            'x-ratelimit-remaining' => '0',
                            'x-ratelimit-reset' => '1700000000',
                          }),
          )
        rescue Clicksign::RateLimitError => e
          err = e
        end
        expect(err.rate_limit_remaining).to eq(0)
        expect(err.rate_limit_reset).to eq('1700000000')
      end
    end
  end
end
