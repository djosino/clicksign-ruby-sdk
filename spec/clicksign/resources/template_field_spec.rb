# frozen_string_literal: true

RSpec.describe Clicksign::Resources::TemplateField do
  include_context 'with clicksign configured'

  let(:template_id) { 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
  let(:field_id)    { 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' }
  let(:template_fields_url) { "#{JsonApiFixtures::BASE_URL}/template_fields" }

  let(:field) do
    template_field_data(
      id: field_id,
      name: 'signer_email',
      kind: 'email',
      template_id: template_id,
    )
  end

  describe '.list' do
    subject(:fields) { described_class.list }

    before do
      stub_request(:get, template_fields_url)
        .to_return(
          status: 200,
          body: collection_resource([field]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(be_a(described_class)) }

    it 'returns records with expected attributes', :aggregate_failures do
      expect(fields.first.id).to eq(field_id)
      expect(fields.first.name).to eq('signer_email')
      expect(fields.first.kind).to eq('email')
    end
  end

  describe '.filter' do
    subject(:fields) { described_class.filter('template.id': template_id).to_a }

    before do
      stub_request(:get, template_fields_url)
        .with(query: { 'filter[template.id]' => template_id })
        .to_return(
          status: 200,
          body: collection_resource([field]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(be_a(described_class)) }
  end
end
