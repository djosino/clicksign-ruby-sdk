# frozen_string_literal: true

RSpec.describe Clicksign::Resources::User do
  include_context 'with clicksign configured'

  let(:user_id) { '11111111-1111-1111-1111-111111111111' }
  let(:second_user_id) { '22222222-2222-2222-2222-222222222222' }
  let(:users_url) { "#{JsonApiFixtures::BASE_URL}/users" }
  let(:user_url) { "#{JsonApiFixtures::BASE_URL}/users/#{user_id}" }
  let(:me_url) { "#{JsonApiFixtures::BASE_URL}/users/me" }

  let(:primary_user) do
    user_data(
      id: user_id,
      name: 'Jane Doe',
      email: 'jane@example.com',
      phone_number: '11987654321',
    )
  end

  let(:secondary_user) do
    user_data(
      id: second_user_id,
      name: 'John Doe',
      email: 'john@example.com',
      phone_number: '11912345678',
    )
  end

  describe '.list' do
    subject(:users) { described_class.list }

    before do
      stub_request(:get, users_url)
        .to_return(
          status: 200,
          body: collection_resource([primary_user, secondary_user]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(be_a(described_class)) }

    it 'returns records with expected attributes', :aggregate_failures do
      expect(users.first.id).to eq(user_id)
      expect(users.first.name).to eq('Jane Doe')
      expect(users.first.email).to eq('jane@example.com')
    end
  end

  describe '.retrieve' do
    before do
      stub_request(:get, user_url)
        .to_return(
          status: 200,
          body: single_resource(primary_user).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'returns the record matching the given id' do
      user = described_class.retrieve(user_id)

      aggregate_failures do
        expect(user).to be_a(described_class)
        expect(user.id).to eq(user_id)
        expect(user.email).to eq('jane@example.com')
      end
    end

    context 'when the user does not exist' do
      before do
        stub_request(:get, "#{JsonApiFixtures::BASE_URL}/users/00000000-0000-0000-0000-000000000000")
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

  describe '.filter' do
    subject(:users) { described_class.filter(email: 'jane@example.com').to_a }

    before do
      stub_request(:get, users_url)
        .with(query: { 'filter[email]' => 'jane@example.com' })
        .to_return(
          status: 200,
          body: collection_resource([primary_user]).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_an(Array) }
    it { is_expected.to all(have_attributes(email: 'jane@example.com')) }
  end

  describe '.create' do
    subject(:user) do
      described_class.create(
        name: 'New User',
        email: 'new@example.com',
        phone_number: '11999998888',
      )
    end

    let(:created_user) do
      user_data(
        id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        name: 'New User',
        email: 'new@example.com',
        phone_number: '11999998888',
      )
    end

    before do
      stub_request(:post, users_url)
        .to_return(
          status: 201,
          body: single_resource(created_user).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_a(described_class) }

    it 'returns a persisted user', :aggregate_failures do
      expect(user.id).to eq('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
      expect(user.name).to eq('New User')
      expect(user.email).to eq('new@example.com')
      expect(user.phone_number).to eq('11999998888')
    end

    it 'posts a JSON:API create payload' do
      user

      expect(WebMock).to(have_requested(:post, users_url).with do |req|
        body = JSON.parse(req.body)
        attrs = body.dig('data', 'attributes')

        body.dig('data', 'type') == 'users' &&
          attrs['name'] == 'New User' &&
          attrs['email'] == 'new@example.com' &&
          attrs['phone_number'] == '11999998888'
      end)
    end

    context 'with invalid attributes' do
      before do
        stub_request(:post, users_url)
          .to_return(
            status: 422,
            body: { errors: [{ detail: 'invalid email' }] }.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' },
          )
      end

      it 'raises ValidationError' do
        expect do
          described_class.create(name: '', email: 'bad', phone_number: '')
        end.to raise_error(Clicksign::ValidationError)
      end
    end
  end

  describe '.me' do
    subject(:me) { described_class.me }

    before do
      stub_request(:get, me_url)
        .to_return(
          status: 200,
          body: single_resource(primary_user).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it { is_expected.to be_a(described_class) }

    it 'returns the current user', :aggregate_failures do
      expect(me.id).to eq(user_id)
      expect(me.email).to eq('jane@example.com')
      expect(me.name).to eq('Jane Doe')
    end

    it 'requests the /users/me endpoint' do
      me

      expect(WebMock).to have_requested(:get, me_url)
    end
  end

  describe '#update' do
    let(:instance) { described_class.send(:build_instance, primary_user) }

    before do
      stub_request(:patch, user_url)
        .to_return(
          status: 200,
          body: single_resource(
            user_data(id: user_id, name: 'Updated Name', email: 'jane@example.com'),
          ).to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' },
        )
    end

    it 'updates and returns the record', :aggregate_failures do
      updated = instance.update(name: 'Updated Name')
      expect(updated).to be_a(described_class)
      expect(updated.name).to eq('Updated Name')
    end
  end

  describe '#delete' do
    let(:instance) { described_class.send(:build_instance, primary_user) }

    before do
      stub_request(:delete, user_url).to_return(status: 204, body: '')
    end

    it 'deletes without raising' do
      expect { instance.delete }.not_to raise_error
    end
  end
end
