# frozen_string_literal: true

RSpec.describe Clicksign::Resources::Template do
  include_context 'with clicksign configured'

  let(:template_id) { 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
  let(:second_template_id) { 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' }
  let(:template_name) { 'Contract Template' }
  let(:templates_url) { "#{JsonApiFixtures::BASE_URL}/templates" }
  let(:template_url) { "#{JsonApiFixtures::BASE_URL}/templates/#{template_id}" }
  let(:template_fields_url) { "#{JsonApiFixtures::BASE_URL}/templates/#{template_id}/template_fields" }

  let(:primary_template) do
    template_data(id: template_id, name: template_name, color: '#577b8d')
  end

  let(:secondary_template) do
    template_data(id: second_template_id, name: 'Other Template', color: '#fccf00')
  end

  describe 'resource configuration' do
    it 'has the correct resource type' do
      expect(described_class.resource_type).to eq('templates')
    end

    it 'has the correct endpoint' do
      expect(described_class.endpoint).to eq('/templates')
    end
  end

  describe '.list' do
    subject(:templates) { described_class.list }

    before do
      stub_request(:get, templates_url)
        .to_return(
          status: 200,
          body: collection_resource([primary_template, secondary_template]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(be_a(described_class)) }

    it 'returns records with expected attributes', :aggregate_failures do
      expect(templates.first.id).to eq(template_id)
      expect(templates.first.name).to eq(template_name)
      expect(templates.first.color).to eq('#577b8d')
    end
  end

  describe '.filter' do
    subject(:templates) { described_class.filter(name: template_name).to_a }

    before do
      stub_request(:get, templates_url)
        .with(query: { 'filter[name]' => template_name })
        .to_return(
          status: 200,
          body: collection_resource([primary_template]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(have_attributes(name: template_name)) }
  end

  describe '.retrieve' do
    before do
      stub_request(:get, template_url)
        .to_return(
          status: 200,
          body: single_resource(primary_template).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns the record matching the given id' do
      template = described_class.retrieve(template_id)

      aggregate_failures do
        expect(template).to be_a(described_class)
        expect(template.id).to eq(template_id)
        expect(template.name).to eq(template_name)
      end
    end

    context 'when the template does not exist' do
      before do
        stub_request(:get, "#{JsonApiFixtures::BASE_URL}/templates/00000000-0000-0000-0000-000000000000")
          .to_return(
            status: 404,
            body: { errors: [{ detail: 'not found' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises NotFoundError' do
        expect do
          described_class.retrieve('00000000-0000-0000-0000-000000000000')
        end.to raise_error(Clicksign::NotFoundError)
      end
    end
  end

  describe '.create' do
    subject(:template) do
      described_class.create(name: 'New Template', content_base64: docx_content_base64,
        color: '#1474f5')
    end

    let(:created_template) do
      template_data(id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', name: 'New Template',
        color: '#1474f5')
    end

    before do
      stub_request(:post, templates_url)
        .to_return(
          status: 201,
          body: single_resource(created_template).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_a(described_class) }

    it 'returns a persisted template', :aggregate_failures do
      expect(template.id).to eq('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
      expect(template.name).to eq('New Template')
      expect(template.color).to eq('#1474f5')
    end

    it 'posts a JSON:API create payload' do
      template

      expect(WebMock).to(have_requested(:post, templates_url).with do |req|
        body = JSON.parse(req.body)
        attrs = body.dig('data', 'attributes')

        body.dig('data', 'type') == 'templates' &&
          attrs['name'] == 'New Template' &&
          attrs['content_base64'] == docx_content_base64 &&
          attrs['color'] == '#1474f5'
      end)
    end

    context 'with invalid attributes' do
      before do
        stub_request(:post, templates_url)
          .to_return(
            status: 422,
            body: { errors: [{ detail: 'invalid content' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises ValidationError' do
        expect do
          described_class.create(name: '', content_base64: 'invalid')
        end.to raise_error(Clicksign::ValidationError)
      end
    end
  end

  describe '#update' do
    subject(:updated) { template.update(name: 'Updated Template', color: '#000000') }

    let(:template) { described_class.send(:build_instance, primary_template) }

    before do
      stub_request(:patch, template_url)
        .to_return(
          status: 200,
          body: single_resource(
            template_data(id: template_id, name: 'Updated Template', color: '#000000'),
          ).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'updates and returns the record', :aggregate_failures do
      expect(updated).to be_a(described_class)
      expect(updated.id).to eq(template_id)
      expect(updated.name).to eq('Updated Template')
      expect(updated.color).to eq('#000000')
    end

    it 'sends only the provided attributes' do
      updated

      expect(WebMock).to(have_requested(:patch, template_url).with do |req|
        attrs = JSON.parse(req.body).dig('data', 'attributes')
        attrs == { 'name' => 'Updated Template', 'color' => '#000000' }
      end)
    end
  end

  describe '#delete' do
    let(:template) { described_class.send(:build_instance, primary_template) }

    before do
      stub_request(:delete, template_url).to_return(status: 204, body: '')
    end

    it 'deletes the template without raising' do
      expect { template.delete }.not_to raise_error
    end

    it 'issues a DELETE request' do
      template.delete

      expect(WebMock).to have_requested(:delete, template_url)
    end
  end

  describe '.list_template_fields' do
    subject(:fields) { described_class.list_template_fields(template_id) }

    let(:field_id) { 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' }

    before do
      stub_request(:get, template_fields_url)
        .to_return(
          status: 200,
          body: collection_resource([
                                      template_field_data(
                                        id: field_id,
                                        name: 'client_name',
                                        kind: 'text',
                                        template_id: template_id,
                                      ),
                                    ]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(be_a(Clicksign::Resources::TemplateField)) }

    it 'returns template fields with expected attributes', :aggregate_failures do
      expect(fields.first.id).to eq(field_id)
      expect(fields.first.name).to eq('client_name')
      expect(fields.first.kind).to eq('text')
    end
  end
end
