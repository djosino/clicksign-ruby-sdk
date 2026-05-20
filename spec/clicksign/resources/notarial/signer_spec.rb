# frozen_string_literal: true

RSpec.describe Clicksign::Resources::Notarial::Signer do
  include_context 'with clicksign configured'

  let(:envelope_id) { 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }
  let(:signer_id) { '33333333-3333-3333-3333-333333333333' }
  let(:signers_url) { "#{JsonApiFixtures::BASE_URL}/envelopes/#{envelope_id}/signers" }
  let(:signer_url) { "#{signers_url}/#{signer_id}" }

  let(:signer) do
    signer_data(id: signer_id, name: 'Spec Signer', email: 'spec@example.com',
                envelope_id: envelope_id)
  end

  describe 'listed via Envelope' do
    subject(:signers) { Clicksign::Resources::Notarial::Envelope.list_signers(envelope_id) }

    before do
      stub_request(:get, signers_url)
        .to_return(
          status: 200,
          body: collection_resource([signer]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to all(be_a(described_class)) }

    it 'sets envelope_id so nested operations work' do
      expect(signers.first.envelope_id).to eq(envelope_id)
    end
  end

  describe '.create with optional attributes' do
    let(:communicate_events_hash) do
      { 'signature_request' => 'email', 'signature_reminder' => 'email',
        'document_signed' => 'email' }
    end

    let(:created_signer) do
      signer_data(
        id: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
        name: 'Full Signer',
        email: 'full@example.com',
        envelope_id: envelope_id,
        phone_number: '11988887777',
        birthday: '1990-05-15',
        refusable: true,
        location_required_enabled: true,
        communicate_events: communicate_events_hash,
        signature_host: 'selfie',
        group: 1,
      )
    end

    before do
      stub_request(:post, signers_url)
        .to_return(
          status: 201,
          body: single_resource(created_signer).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'exposes all optional attributes', :aggregate_failures do
      instance = described_class.create(
        envelope_id: envelope_id,
        name: 'Full Signer',
        email: 'full@example.com',
        phone_number: '11988887777',
        birthday: '1990-05-15',
        refusable: true,
        location_required_enabled: true,
        communicate_events: { signature_request: 'email', signature_reminder: 'email',
                              document_signed: 'email' },
        signature_host: 'selfie',
        group: 1,
      )

      expect(instance.phone_number).to eq('11988887777')
      expect(instance.birthday).to eq('1990-05-15')
      expect(instance.refusable).to be(true)
      expect(instance.location_required_enabled).to be(true)
      expect(instance.communicate_events).to eq(communicate_events_hash)
      expect(instance.signature_host).to eq('selfie')
      expect(instance.group).to eq(1)
    end
  end

  describe '.create and #delete' do
    let(:created_signer) do
      signer_data(
        id: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
        name: 'Spec Signer',
        email: 'spec@example.com',
        envelope_id: envelope_id,
      )
    end

    before do
      stub_request(:post, signers_url)
        .to_return(
          status: 201,
          body: single_resource(created_signer).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
      stub_request(:delete, "#{signers_url}/cccccccc-cccc-cccc-cccc-cccccccccccc")
        .to_return(status: 204, body: '')
    end

    it 'creates and deletes a signer without raising', :aggregate_failures do
      instance = described_class.create(
        envelope_id: envelope_id,
        name: 'Spec Signer',
        email: 'spec@example.com',
      )

      expect(instance).to be_a(described_class)
      expect(instance.name).to eq('Spec Signer')
      expect(instance.envelope_id).to eq(envelope_id)
      expect { instance.delete }.not_to raise_error
    end
  end

  describe '.retrieve' do
    before do
      stub_request(:get, signer_url)
        .to_return(
          status: 200,
          body: single_resource(signer).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns the signer matching the given id' do
      expect(described_class.retrieve(signer_id,
                                      envelope_id: envelope_id).id).to eq(signer_id)
    end

    context 'when the signer does not exist' do
      before do
        stub_request(:get, "#{signers_url}/00000000-0000-0000-0000-000000000000")
          .to_return(
            status: 404,
            body: { errors: [{ detail: 'not found' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises NotFoundError' do
        expect do
          described_class.retrieve('00000000-0000-0000-0000-000000000000',
                                   envelope_id: envelope_id)
        end.to raise_error(Clicksign::NotFoundError)
      end
    end
  end

  describe '#reload' do
    let(:instance) do
      described_class.send(:build_instance, signer, parent_id: envelope_id)
    end

    before do
      stub_request(:get, signer_url)
        .to_return(
          status: 200,
          body: single_resource(signer).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'refreshes the record and preserves envelope_id' do
      reloaded = instance.reload
      expect(reloaded.envelope_id).to eq(envelope_id)
    end
  end

  describe '.notify and #notify' do
    let(:notifications_url) { "#{signer_url}/notifications" }
    let(:instance) do
      described_class.send(:build_instance, signer, parent_id: envelope_id)
    end

    before do
      stub_request(:post, notifications_url)
        .to_return(status: 201, body: '')
    end

    it '.notify posts to the correct URL without raising' do
      expect do
        described_class.notify(signer_id, envelope_id: envelope_id,
                                          message: 'Please sign')
      end.not_to raise_error
    end

    it '#notify posts from the instance without raising' do
      expect { instance.notify(message: 'Please sign') }.not_to raise_error
    end

    it '#notify sends a POST to the correct URL' do
      instance.notify(message: 'Please sign')
      expect(WebMock).to have_requested(:post, notifications_url)
    end
  end

  describe '#envelope_id' do
    context 'when built with parent_id (nested list path)' do
      let(:instance) do
        described_class.send(:build_instance, signer, parent_id: envelope_id)
      end

      it 'returns the parent_id' do
        expect(instance.envelope_id).to eq(envelope_id)
      end
    end

    context 'when built without parent_id (relationship path)' do
      let(:instance) do
        described_class.send(:build_instance,
                             signer_data(id: signer_id, name: 'Jane Doe',
                                         email: 'jane@example.com',
                                         envelope_id: envelope_id))
      end

      it 'returns the id from the envelope relationship' do
        expect(instance.envelope_id).to eq(envelope_id)
      end
    end
  end

  describe '#update' do
    let(:instance) do
      described_class.send(:build_instance, signer, parent_id: envelope_id)
    end

    it 'raises NotImplementedError' do
      expect { instance.update(name: 'New Name') }.to raise_error(NotImplementedError)
    end
  end
end
