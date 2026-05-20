# frozen_string_literal: true

RSpec.describe Clicksign::Resources::Notarial::Envelope do
  include_context 'with clicksign configured'

  let(:envelope_id) { 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
  let(:second_envelope_id) { 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' }
  let(:folder_id) { '11111111-1111-1111-1111-111111111111' }
  let(:document_id) { '22222222-2222-2222-2222-222222222222' }
  let(:signer_id) { '33333333-3333-3333-3333-333333333333' }

  let(:envelopes_url) { "#{JsonApiFixtures::BASE_URL}/envelopes" }
  let(:envelope_url) { "#{JsonApiFixtures::BASE_URL}/envelopes/#{envelope_id}" }

  let(:draft_envelope) do
    envelope_data(id: envelope_id, name: 'Draft Envelope', status: 'draft')
  end

  let(:running_envelope) do
    envelope_data(id: second_envelope_id, name: 'Running Envelope', status: 'running')
  end

  describe '.list' do
    subject(:envelopes) { described_class.list }

    before do
      stub_request(:get, envelopes_url)
        .to_return(
          status: 200,
          body: collection_resource([draft_envelope, running_envelope]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(be_a(described_class)) }

    it 'returns records with expected attributes', :aggregate_failures do
      expect(envelopes.first.id).to eq(envelope_id)
      expect(envelopes.first.name).to eq('Draft Envelope')
      expect(envelopes.first.status).to eq('draft')
    end
  end

  describe '.filter' do
    context 'with status: running' do
      subject(:envelopes) { described_class.filter(status: 'running').to_a }

      before do
        stub_request(:get, envelopes_url)
          .with(query: { 'filter[status]' => 'running' })
          .to_return(
            status: 200,
            body: collection_resource([running_envelope]).to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it { is_expected.to all(have_attributes(status: 'running')) }
    end

    context 'with status: draft' do
      subject(:envelopes) { described_class.filter(status: 'draft').to_a }

      before do
        stub_request(:get, envelopes_url)
          .with(query: { 'filter[status]' => 'draft' })
          .to_return(
            status: 200,
            body: collection_resource([draft_envelope]).to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it { is_expected.to all(have_attributes(status: 'draft')) }
    end
  end

  describe '.order' do
    before do
      stub_request(:get, envelopes_url)
        .with(query: hash_including('sort' => 'name'))
        .to_return(
          status: 200,
          body: collection_resource([draft_envelope]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'requests sorted results' do
      described_class.order('name').to_a

      expect(WebMock).to have_requested(:get, envelopes_url)
        .with(query: hash_including('sort' => 'name'))
    end
  end

  describe '.page and .per' do
    before do
      stub_request(:get, envelopes_url)
        .with(query: { 'page[number]' => '1', 'page[size]' => '2' })
        .to_return(
          status: 200,
          body: collection_resource([draft_envelope]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
      stub_request(:get, envelopes_url)
        .with(query: { 'page[number]' => '2', 'page[size]' => '2' })
        .to_return(
          status: 200,
          body: collection_resource([running_envelope]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'passes pagination params' do
      described_class.page(1).per(2).to_a

      expect(WebMock).to have_requested(:get, envelopes_url)
        .with(query: { 'page[number]' => '1', 'page[size]' => '2' })
    end

    it 'returns different results for different pages' do
      page1 = described_class.page(1).per(2).to_a.map(&:id)
      page2 = described_class.page(2).per(2).to_a.map(&:id)
      expect(page1).not_to eq(page2)
    end
  end

  describe 'attribute bracket accessor #[]' do
    let(:envelope) { described_class.send(:build_instance, draft_envelope) }

    it 'returns the attribute value by string key' do
      expect(envelope['name']).to eq('Draft Envelope')
    end

    it 'returns the attribute value by symbol-like string' do
      expect(envelope['status']).to eq('draft')
    end

    it 'returns nil for unknown keys' do
      expect(envelope['nonexistent']).to be_nil
    end
  end

  describe 'QueryProxy #fields and #include' do
    before do
      stub_request(:get, envelopes_url)
        .with(query: { 'fields[envelopes]' => 'name,status' })
        .to_return(
          status: 200,
          body: collection_resource([draft_envelope]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
      stub_request(:get, envelopes_url)
        .with(query: { 'include' => 'folder' })
        .to_return(
          status: 200,
          body: collection_resource([draft_envelope]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it '#fields sends sparse fieldset params' do
      described_class.fields(envelopes: %w[name status]).to_a
      expect(WebMock).to have_requested(:get, envelopes_url)
        .with(query: { 'fields[envelopes]' => 'name,status' })
    end

    it '#include sends the include param' do
      described_class.include('folder').to_a
      expect(WebMock).to have_requested(:get, envelopes_url)
        .with(query: { 'include' => 'folder' })
    end
  end

  describe 'QueryProxy #last and #count' do
    before do
      stub_request(:get, envelopes_url)
        .with(query: { 'filter[status]' => 'draft' })
        .to_return(
          status: 200,
          body: collection_resource([draft_envelope, running_envelope]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
      stub_request(:get, envelopes_url)
        .with(query: { 'sort' => 'name' })
        .to_return(
          status: 200,
          body: collection_resource([draft_envelope, running_envelope]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it '#last returns the final element' do
      expect(described_class.filter(status: 'draft').last).to be_a(described_class)
    end

    it '#count returns the number of records' do
      expect(described_class.order('name').count).to eq(2)
    end
  end

  describe '.retrieve' do
    before do
      stub_request(:get, envelope_url)
        .to_return(
          status: 200,
          body: single_resource(draft_envelope).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns the record matching the given id' do
      expect(described_class.retrieve(envelope_id).id).to eq(envelope_id)
    end

    context 'when the envelope does not exist' do
      before do
        stub_request(:get, "#{JsonApiFixtures::BASE_URL}/envelopes/00000000-0000-0000-0000-000000000000")
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
    let(:created_envelope) do
      envelope_data(id: 'cccccccc-cccc-cccc-cccc-cccccccccccc', name: 'Spec Envelope',
                    status: 'draft')
    end

    before do
      stub_request(:post, envelopes_url)
        .to_return(
          status: 201,
          body: single_resource(created_envelope).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns a persisted draft envelope', :aggregate_failures do
      envelope = described_class.create(name: 'Spec Envelope')

      expect(envelope).to be_a(described_class)
      expect(envelope.id).to eq('cccccccc-cccc-cccc-cccc-cccccccccccc')
      expect(envelope.status).to eq('draft')
    end

    context 'with a folder relationship' do
      let(:created_with_folder) do
        envelope_data(
          id: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
          name: 'Spec With Folder',
          status: 'draft',
          folder_id: folder_id,
        )
      end

      before do
        stub_request(:post, envelopes_url)
          .to_return(
            status: 201,
            body: single_resource(created_with_folder).to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'posts the folder relationship' do
        envelope = described_class.create(name: 'Spec With Folder', folder_id: folder_id)

        expect(envelope.folder_id).to eq(folder_id)
        expect(WebMock).to(have_requested(:post, envelopes_url).with do |req|
          JSON.parse(req.body).dig('data', 'relationships', 'folder', 'data',
                                   'id') == folder_id
        end)
      end
    end

    context 'with invalid attributes' do
      before do
        stub_request(:post, envelopes_url)
          .to_return(
            status: 422,
            body: { errors: [{ detail: 'invalid' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises ValidationError when name is blank' do
        expect { described_class.create(name: '') }.to raise_error(Clicksign::ValidationError)
      end
    end
  end

  describe '.create with optional attributes' do
    let(:full_envelope) do
      envelope_data(
        id: 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
        name: 'Full Envelope',
        status: 'draft',
        remind_interval: 3,
        block_after_refusal: true,
        auto_close: true,
        locale: 'en-US',
        metadata: 'ref=123',
        default_subject: 'Please sign',
        default_message: 'Kindly review and sign.',
      )
    end

    before do
      stub_request(:post, envelopes_url)
        .to_return(
          status: 201,
          body: single_resource(full_envelope).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'exposes all optional attributes', :aggregate_failures do
      envelope = described_class.create(
        name: 'Full Envelope',
        remind_interval: 3,
        block_after_refusal: true,
        auto_close: true,
        locale: 'en-US',
        metadata: 'ref=123',
        default_subject: 'Please sign',
        default_message: 'Kindly review and sign.',
      )

      expect(envelope.remind_interval).to eq(3)
      expect(envelope.block_after_refusal).to be(true)
      expect(envelope.auto_close).to be(true)
      expect(envelope.locale).to eq('en-US')
      expect(envelope.metadata).to eq('ref=123')
      expect(envelope.default_subject).to eq('Please sign')
      expect(envelope.default_message).to eq('Kindly review and sign.')
    end
  end

  describe '#folder_id' do
    context 'when folder relationship is present' do
      let(:envelope) do
        described_class.send(:build_instance,
                             envelope_data(id: envelope_id, name: 'With Folder',
                                           folder_id: folder_id))
      end

      it 'returns the folder id' do
        expect(envelope.folder_id).to eq(folder_id)
      end
    end

    context 'when folder relationship is absent' do
      let(:envelope) { described_class.send(:build_instance, draft_envelope) }

      it 'returns nil' do
        expect(envelope.folder_id).to be_nil
      end
    end
  end

  describe '#update' do
    subject(:updated) { envelope.update(name: 'Updated Name') }

    let(:envelope) { described_class.send(:build_instance, draft_envelope) }

    before do
      stub_request(:patch, envelope_url)
        .to_return(
          status: 200,
          body: single_resource(
            envelope_data(id: envelope_id, name: 'Updated Name', status: 'draft'),
          ).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'updates and returns the record', :aggregate_failures do
      expect(updated.name).to eq('Updated Name')
      expect(updated.id).to eq(envelope_id)
    end
  end

  describe '#delete' do
    let(:envelope) { described_class.send(:build_instance, draft_envelope) }

    before do
      stub_request(:delete, envelope_url).to_return(status: 204, body: '')
    end

    it 'deletes the envelope without raising' do
      expect { envelope.delete }.not_to raise_error
    end
  end

  describe '.activate' do
    before do
      stub_request(:post, "#{envelope_url}/activate")
        .to_return(
          status: 200,
          body: single_resource(
            envelope_data(id: envelope_id, name: 'Draft Envelope', status: 'running'),
          ).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns the envelope with status running' do
      result = described_class.activate(envelope_id)
      expect(result.status).to eq('running')
    end
  end

  describe '.notify' do
    let(:notifications_url) { "#{envelope_url}/notifications" }

    before do
      stub_request(:post, notifications_url)
        .to_return(status: 201, body: { data: { type: 'notifications' } }.to_json)
    end

    it 'posts a notification without raising' do
      expect do
        described_class.notify(envelope_id, message: 'Please sign')
      end.not_to raise_error
    end

    it 'includes email_customization in the request body when provided' do
      described_class.notify(envelope_id, message: 'Please sign',
                                          subject: 'Sign now', body: 'Hello')

      expect(WebMock).to(have_requested(:post, notifications_url).with do |req|
        attrs = JSON.parse(req.body).dig('data', 'attributes')
        attrs['email_customization'] == { 'subject' => 'Sign now', 'body' => 'Hello' }
      end)
    end

    it 'omits email_customization when no kwargs given' do
      described_class.notify(envelope_id, message: 'Please sign')

      expect(WebMock).to(have_requested(:post, notifications_url).with do |req|
        attrs = JSON.parse(req.body).dig('data', 'attributes')
        !attrs.key?('email_customization')
      end)
    end
  end

  describe '#notify' do
    let(:notifications_url) { "#{envelope_url}/notifications" }
    let(:envelope) { described_class.send(:build_instance, draft_envelope) }

    before do
      stub_request(:post, notifications_url)
        .to_return(status: 201, body: '')
    end

    it 'posts a notification from the instance without raising' do
      expect { envelope.notify(message: 'Please sign') }.not_to raise_error
    end

    it 'sends a POST to the correct URL' do
      envelope.notify(message: 'Please sign')

      expect(WebMock).to have_requested(:post, notifications_url)
    end
  end

  describe '.list_documents' do
    let(:documents_url) { "#{envelope_url}/documents" }
    let(:document) do
      document_data(id: document_id, filename: 'contract.pdf', envelope_id: envelope_id)
    end

    before do
      stub_request(:get, documents_url)
        .to_return(
          status: 200,
          body: collection_resource([document]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns documents with envelope_id set', :aggregate_failures do
      documents = described_class.list_documents(envelope_id)

      expect(documents).to all(be_a(Clicksign::Resources::Notarial::Document))
      expect(documents.first.envelope_id).to eq(envelope_id)
    end

    context 'with filter params' do
      before do
        stub_request(:get, documents_url)
          .with(query: { 'filter[status]' => 'draft' })
          .to_return(
            status: 200,
            body: collection_resource([document]).to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'forwards filter params to the request' do
        described_class.list_documents(envelope_id, status: 'draft')

        expect(WebMock).to have_requested(:get, documents_url)
          .with(query: { 'filter[status]' => 'draft' })
      end
    end
  end

  describe '.list_signers' do
    let(:signers_url) { "#{envelope_url}/signers" }
    let(:signer) do
      signer_data(id: signer_id, name: 'Jane', email: 'jane@example.com',
                  envelope_id: envelope_id)
    end

    before do
      stub_request(:get, signers_url)
        .to_return(
          status: 200,
          body: collection_resource([signer]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns signers with envelope_id set' do
      signers = described_class.list_signers(envelope_id)
      expect(signers.first.envelope_id).to eq(envelope_id)
    end
  end

  describe '.list_signature_watchers' do
    let(:watchers_url) { "#{envelope_url}/signature_watchers" }
    let(:watcher) do
      signature_watcher_data(
        id: '44444444-4444-4444-4444-444444444444',
        email: 'watcher@example.com',
        kind: 'all_steps',
        envelope_id: envelope_id,
      )
    end

    before do
      stub_request(:get, watchers_url)
        .to_return(
          status: 200,
          body: collection_resource([watcher]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns signature watchers' do
      expect(described_class.list_signature_watchers(envelope_id)).to all(
        be_a(Clicksign::Resources::Notarial::SignatureWatcher),
      )
    end
  end

  describe '.list_events' do
    let(:events_url) { "#{envelope_url}/events" }
    let(:event) do
      event_data(id: '66666666-6666-6666-6666-666666666666', name: 'sign',
                 envelope_id: envelope_id)
    end

    before do
      stub_request(:get, events_url)
        .to_return(
          status: 200,
          body: collection_resource([event]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns events for the envelope' do
      events = described_class.list_events(envelope_id)
      expect(events.first.name).to eq('sign')
    end

    it 'returns Event instances' do
      expect(described_class.list_events(envelope_id))
        .to all(be_a(Clicksign::Resources::Notarial::Event))
    end
  end

  describe '.list_requirements' do
    let(:requirements_url) { "#{envelope_url}/requirements" }
    let(:requirement) do
      requirement_data(
        id: '55555555-5555-5555-5555-555555555555',
        action: 'agree',
        role: 'sign',
        envelope_id: envelope_id,
        document_id: document_id,
        signer_id: signer_id,
      )
    end

    before do
      stub_request(:get, requirements_url)
        .to_return(
          status: 200,
          body: collection_resource([requirement]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns requirements for the envelope' do
      requirements = described_class.list_requirements(envelope_id)
      expect(requirements.first.action).to eq('agree')
    end
  end
end
