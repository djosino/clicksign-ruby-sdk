# frozen_string_literal: true

RSpec.describe Clicksign::Resources::Folder do
  include_context 'with clicksign configured'

  let(:folder_id)  { 'f1111111-1111-1111-1111-111111111111' }
  let(:parent_id)  { 'f2222222-2222-2222-2222-222222222222' }
  let(:child_id)   { 'f3333333-3333-3333-3333-333333333333' }
  let(:folders_url) { "#{JsonApiFixtures::BASE_URL}/folders" }
  let(:folder_url)  { "#{folders_url}/#{folder_id}" }

  let(:root_folder) do
    folder_data(id: folder_id, name: 'Root Folder', path: '/', in_root: true)
  end

  let(:child_folder) do
    folder_data(id: child_id, name: 'Child Folder',
                path: '/Root Folder', in_root: false)
  end

  describe 'resource configuration' do
    it 'has the correct resource type' do
      expect(described_class.resource_type).to eq('folders')
    end

    it 'has the correct endpoint' do
      expect(described_class.endpoint).to eq('/folders')
    end
  end

  describe '.list' do
    subject(:folders) { described_class.list }

    before do
      stub_request(:get, folders_url)
        .to_return(
          status: 200,
          body: collection_resource([root_folder, child_folder]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(be_a(described_class)) }

    it 'returns records with expected attributes', :aggregate_failures do
      expect(folders.first.id).to eq(folder_id)
      expect(folders.first.name).to eq('Root Folder')
    end
  end

  describe '.filter' do
    context 'with in_root: true' do
      subject(:folders) { described_class.filter(in_root: true).to_a }

      before do
        stub_request(:get, folders_url)
          .with(query: { 'filter[in_root]' => 'true' })
          .to_return(
            status: 200,
            body: collection_resource([root_folder]).to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it { is_expected.to be_an(Array) }
      it { is_expected.to all(have_attributes(in_root: true)) }
    end
  end

  describe '.retrieve' do
    before do
      stub_request(:get, folder_url)
        .to_return(
          status: 200,
          body: single_resource(root_folder).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns the record matching the given id' do
      expect(described_class.retrieve(folder_id).id).to eq(folder_id)
    end

    context 'when the folder does not exist' do
      before do
        stub_request(:get, "#{folders_url}/00000000-0000-0000-0000-000000000000")
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
    let(:created_folder) do
      folder_data(id: folder_id, name: 'Spec Folder', path: '/', in_root: true)
    end

    before do
      stub_request(:post, folders_url)
        .to_return(
          status: 201,
          body: single_resource(created_folder).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns a persisted folder', :aggregate_failures do
      folder = described_class.create(name: 'Spec Folder')

      expect(folder).to be_a(described_class)
      expect(folder.id).to eq(folder_id)
      expect(folder.name).to eq('Spec Folder')
    end

    context 'nested under a parent folder' do
      let(:nested_folder) do
        folder_data(id: child_id, name: 'Child Folder',
                    path: '/Root Folder', in_root: false)
      end

      before do
        stub_request(:post, folders_url)
          .to_return(
            status: 201,
            body: single_resource(nested_folder).to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'creates a folder linked to the parent', :aggregate_failures do
        child = described_class.create(name: 'Child Folder', folder_id: parent_id)

        expect(child).to be_a(described_class)
        expect(child.id).to eq(child_id)
        expect(WebMock).to(have_requested(:post, folders_url).with do |req|
          JSON.parse(req.body).dig('data', 'relationships', 'folder', 'data',
                                   'id') == parent_id
        end)
      end
    end
  end

  describe '#update' do
    let(:instance) { described_class.send(:build_instance, root_folder) }

    before do
      stub_request(:patch, folder_url)
        .to_return(
          status: 200,
          body: single_resource(
            folder_data(id: folder_id, name: 'Renamed Folder'),
          ).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'updates and returns the record', :aggregate_failures do
      updated = instance.update(name: 'Renamed Folder')
      expect(updated).to be_a(described_class)
      expect(updated.name).to eq('Renamed Folder')
    end
  end

  describe '#delete' do
    let(:instance) { described_class.send(:build_instance, root_folder) }

    before do
      stub_request(:delete, folder_url).to_return(status: 204, body: '')
    end

    it 'deletes without raising' do
      expect { instance.delete }.not_to raise_error
    end
  end

  describe '#child_folder_ids' do
    let(:folder_with_children) do
      data = folder_data(id: folder_id, name: 'Root Folder', path: '/', in_root: true)
      data['relationships'] = {
        'folders' => {
          'data' => [
            { 'type' => 'folders', 'id' => child_id },
            { 'type' => 'folders', 'id' => parent_id },
          ],
        },
      }
      described_class.send(:build_instance, data)
    end

    let(:folder_without_children) do
      described_class.send(:build_instance, root_folder)
    end

    it 'returns ids of child folders' do
      expect(folder_with_children.child_folder_ids).to eq([child_id, parent_id])
    end

    it 'returns an empty array when there are no children' do
      expect(folder_without_children.child_folder_ids).to eq([])
    end
  end
end
