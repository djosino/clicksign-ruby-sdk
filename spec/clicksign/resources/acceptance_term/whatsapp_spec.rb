# frozen_string_literal: true

RSpec.describe Clicksign::Resources::AcceptanceTerm::Whatsapp do
  include_context 'with clicksign configured'

  let(:whatsapps_url) { "#{JsonApiFixtures::BASE_URL}/acceptance_term/whatsapps" }
  let(:whatsapp_id)   { 'a1111111-1111-1111-1111-111111111111' }

  it 'has the correct resource type' do
    expect(described_class.resource_type).to eq('acceptance_term_whatsapps')
  end

  it 'has the correct endpoint' do
    expect(described_class.endpoint).to eq('/acceptance_term/whatsapps')
  end

  describe '.list' do
    subject(:whatsapps) { described_class.list }

    before do
      stub_request(:get, whatsapps_url)
        .to_return(
          status: 200,
          body: collection_resource([whatsapp_data(id: whatsapp_id)]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(be_a(described_class)) }
  end
end
