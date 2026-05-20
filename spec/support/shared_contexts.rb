# frozen_string_literal: true

RSpec.shared_context 'with clicksign configured' do
  include JsonApiFixtures

  before do
    Clicksign.configure do |c|
      c.api_key  = 'test-token'
      c.base_url = JsonApiFixtures::BASE_URL
    end
  end
end
