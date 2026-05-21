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

  describe 'resource configuration' do
    it 'has the correct resource type' do
      expect(described_class.resource_type).to eq('template_fields')
    end

    it 'has the correct endpoint' do
      expect(described_class.endpoint).to eq('/template_fields')
    end
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

  describe '#update' do
    let(:field_url) { "#{template_fields_url}/#{field_id}" }
    let(:instance)  { described_class.send(:build_instance, field) }

    before do
      stub_request(:patch, field_url)
        .to_return(
          status: 200,
          body: single_resource(
            template_field_data(id: field_id, name: 'updated_name', kind: 'email',
              template_id: template_id),
          ).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'updates and returns the record', :aggregate_failures do
      updated = instance.update(name: 'updated_name')
      expect(updated).to be_a(described_class)
      expect(updated.name).to eq('updated_name')
    end

    context 'with invalid attributes' do
      before do
        stub_request(:patch, field_url)
          .to_return(
            status: 422,
            body: { errors: [{ detail: 'name is too long' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises ValidationError' do
        expect { instance.update(name: 'x' * 300) }
          .to raise_error(Clicksign::ValidationError, 'name is too long')
      end
    end
  end

  describe '#delete' do
    let(:field_url) { "#{template_fields_url}/#{field_id}" }
    let(:instance)  { described_class.send(:build_instance, field) }

    before do
      stub_request(:delete, field_url).to_return(status: 204, body: '')
    end

    it 'deletes without raising' do
      expect { instance.delete }.not_to raise_error
    end

    context 'when the field does not exist' do
      before do
        stub_request(:delete, field_url)
          .to_return(
            status: 404,
            body: { errors: [{ detail: 'not found' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises NotFoundError' do
        expect { instance.delete }.to raise_error(Clicksign::NotFoundError)
      end
    end
  end

  describe '#[]' do
    let(:instance) { described_class.send(:build_instance, field) }

    it 'accesses an attribute by string key' do
      expect(instance['name']).to eq('signer_email')
    end

    it 'accesses an attribute by symbol key stringified' do
      expect(instance['kind']).to eq('email')
    end

    it 'returns nil for an unknown key' do
      expect(instance['nonexistent']).to be_nil
    end
  end
end
