# frozen_string_literal: true

RSpec.describe Clicksign::Resource do
  # Minimal concrete subclass for testing base Resource behaviour
  let(:klass) do
    Class.new(described_class) do
      self.resource_type = 'widgets'
    end
  end

  let(:raw) do
    {
      'id' => 'abc-123',
      'type' => 'widgets',
      'attributes' => { 'name' => 'Sprocket', 'active' => true },
      'relationships' => { 'owner' => { 'data' => { 'id' => 'u-1' } } },
    }
  end

  let(:instance) { klass.send(:build_instance, raw) }

  describe 'attribute access via method_missing' do
    it 'reads a string attribute' do
      expect(instance.name).to eq('Sprocket')
    end

    it 'reads a boolean attribute' do
      expect(instance.active).to be(true)
    end

    it 'raises NoMethodError for unknown attributes' do
      expect { instance.nonexistent }.to raise_error(NoMethodError)
    end

    it 'writes a known attribute via setter' do
      instance.name = 'Updated'
      expect(instance.name).to eq('Updated')
    end

    it 'raises NoMethodError for unknown attribute setter' do
      expect { instance.nonexistent = 'value' }.to raise_error(NoMethodError)
    end
  end

  describe '#respond_to_missing?' do
    it 'returns true for a known attribute' do
      expect(instance.respond_to?(:name)).to be(true)
    end

    it 'returns true for a known attribute as string' do
      expect(instance.respond_to?('active')).to be(true)
    end

    it 'returns false for an unknown attribute' do
      expect(instance.respond_to?(:nonexistent)).to be(false)
    end
  end

  describe '.infer_resource_type' do
    it 'underscores and pluralises a simple class name' do
      klass_no_type = Class.new(described_class)
      allow(klass_no_type).to receive(:name).and_return('Clicksign::Resources::Webhook')
      expect(klass_no_type.resource_type).to eq('webhooks')
    end

    it 'handles multi-word names (CamelCase → snake_case + plural)' do
      klass_no_type = Class.new(described_class)
      allow(klass_no_type).to receive(:name)
        .and_return('Clicksign::Resources::SignatureWatcher')
      expect(klass_no_type.resource_type).to eq('signature_watchers')
    end

    it 'prefers an explicit resource_type over inference' do
      expect(klass.resource_type).to eq('widgets')
    end

    it 'defaults to resources when the class is anonymous (name is nil)' do
      anonymous = Class.new(described_class)

      expect(anonymous.name).to be_nil
      expect(anonymous.resource_type).to eq('resources')
      expect(anonymous.endpoint).to eq('/resources')
    end
  end

  describe '.list' do
    include_context 'with clicksign configured'

    let(:url) { "#{JsonApiFixtures::BASE_URL}/widgets" }
    let(:json_headers) { { 'Content-Type' => 'application/vnd.api+json' } }
    let(:body) do
      {
        'data' => [
          { 'id' => '1', 'type' => 'widgets', 'attributes' => { 'name' => 'A' },
            'relationships' => {} },
        ],
      }.to_json
    end

    before do
      stub_request(:get, url)
        .to_return(status: 200, body: body, headers: json_headers)
    end

    it 'returns an Array of instances' do
      result = klass.list
      expect(result).to be_an(Array)
      expect(result).to all(be_a(klass))
    end

    it 'does not accept filter kwargs' do
      expect { klass.list(status: 'draft') }.to raise_error(ArgumentError)
    end
  end

  describe '.endpoint' do
    it 'defaults to /resource_type' do
      expect(klass.endpoint).to eq('/widgets')
    end

    it 'can be overridden explicitly' do
      klass.endpoint = '/custom/path'
      expect(klass.endpoint).to eq('/custom/path')
    end
  end

  describe '#id and #relationships' do
    it 'exposes id' do
      expect(instance.id).to eq('abc-123')
    end

    it 'exposes relationships' do
      expect(instance.relationships).to eq('owner' => { 'data' => { 'id' => 'u-1' } })
    end
  end

  describe '#base_path' do
    it 'defaults to the class endpoint' do
      expect(instance.base_path).to eq('/widgets')
    end
  end

  describe '.build_instance with nil data' do
    it 'raises NotFoundError instead of NoMethodError when API returns null data' do
      expect { klass.send(:build_instance, nil) }
        .to raise_error(Clicksign::NotFoundError, /null data/)
    end
  end

  describe 'QueryProxy chain methods' do
    include_context 'with clicksign configured'

    let(:url)          { "#{JsonApiFixtures::BASE_URL}/widgets" }
    let(:json_headers) { { 'Content-Type' => 'application/vnd.api+json' } }
    let(:body) do
      { 'data' => [{ 'id' => '1', 'type' => 'widgets', 'attributes' => { 'name' => 'W' },
                     'relationships' => {} }] }
    end

    describe '.order' do
      it 'passes sort param to the request' do
        stub_request(:get, url)
          .with(query: { 'sort' => 'name' })
          .to_return(status: 200, body: body.to_json, headers: json_headers)

        klass.order('name').to_a
        expect(WebMock).to have_requested(:get, url).with(query: { 'sort' => 'name' })
      end

      it 'returns a QueryProxy' do
        expect(klass.order('name')).to be_a(Clicksign::Resource::QueryProxy)
      end
    end

    describe '.with_includes' do
      it 'passes include param to the request' do
        stub_request(:get, url)
          .with(query: { 'include' => 'owner,tags' })
          .to_return(status: 200, body: body.to_json, headers: json_headers)

        klass.with_includes('owner', 'tags').to_a
        expect(WebMock).to have_requested(:get,
          url).with(query: { 'include' => 'owner,tags' })
      end

      it 'returns a QueryProxy' do
        expect(klass.with_includes('owner')).to be_a(Clicksign::Resource::QueryProxy)
      end
    end

    describe '.include' do
      it 'delegates JSON:API types to with_includes' do
        stub_request(:get, url)
          .with(query: { 'include' => 'owner' })
          .to_return(status: 200, body: body.to_json, headers: json_headers)

        klass.include('owner').to_a
        expect(WebMock).to have_requested(:get, url).with(query: { 'include' => 'owner' })
      end

      it 'mixes Ruby modules without shadowing Module#include' do
        mod = Module.new do
          def self.included(base)
            base.define_method(:from_mixin) { true }
          end
        end

        sub = Class.new(klass) { include mod }

        expect(sub.included_modules).to include(mod)
        expect(sub.new.from_mixin).to be(true)
      end

      it 'raises when mixing Module with JSON:API include types' do
        mod = Module.new

        expect { klass.include(mod, 'owner') }
          .to raise_error(ArgumentError, /cannot mix Module/)
      end
    end

    describe '.fields' do
      it 'passes fields[type] param to the request' do
        stub_request(:get, url)
          .with(query: { 'fields[widgets]' => 'name' })
          .to_return(status: 200, body: body.to_json, headers: json_headers)

        klass.fields(widgets: %w[name]).to_a
        expect(WebMock).to have_requested(:get, url)
          .with(query: { 'fields[widgets]' => 'name' })
      end

      it 'returns a QueryProxy' do
        expect(klass.fields(widgets: %w[name])).to be_a(Clicksign::Resource::QueryProxy)
      end
    end

    describe '.page and .per' do
      it '.page returns a QueryProxy' do
        expect(klass.page(2)).to be_a(Clicksign::Resource::QueryProxy)
      end

      it '.per returns a QueryProxy' do
        expect(klass.per(50)).to be_a(Clicksign::Resource::QueryProxy)
      end

      it 'passes page[number] and page[size] to the request' do
        stub_request(:get, url)
          .with(query: { 'page[number]' => '2', 'page[size]' => '10' })
          .to_return(status: 200, body: body.to_json, headers: json_headers)

        klass.page(2).per(10).to_a
        expect(WebMock).to have_requested(:get, url)
          .with(query: { 'page[number]' => '2', 'page[size]' => '10' })
      end
    end

    describe 'QueryProxy terminal methods' do
      before do
        stub_request(:get, url)
          .with(query: { 'sort' => 'name' })
          .to_return(status: 200, body: body.to_json, headers: json_headers)
      end

      it '#first returns the first record' do
        expect(klass.order('name').first).to be_a(klass)
      end

      it '#last returns the last record' do
        expect(klass.order('name').last).to be_a(klass)
      end

      it '#count returns the number of records' do
        expect(klass.order('name').count).to eq(1)
      end
    end
  end

  describe 'auto-pagination' do
    include_context 'with clicksign configured'

    let(:url)          { "#{JsonApiFixtures::BASE_URL}/widgets" }
    let(:json_headers) { { 'Content-Type' => 'application/vnd.api+json' } }

    # links_next: :omit (no links key), nil (last page), or URL string
    def page_body(*ids, links_next: :omit)
      body = {
        'data' => ids.map do |n|
          { 'id' => "id-#{n}", 'type' => 'widgets',
            'attributes' => { 'name' => "Widget #{n}" } }
        end,
      }
      body['links'] = { 'next' => links_next } unless links_next == :omit
      body.to_json
    end

    before do
      params = '?page%5Bnumber%5D=2&page%5Bsize%5D=2'

      stub_request(:get, url)
        .with(query: { 'page[number]' => '1', 'page[size]' => '2' })
        .to_return(status: 200,
          body: page_body(1, 2,
            links_next: "#{url}#{params}"),
          headers: json_headers)
      stub_request(:get, url)
        .with(query: { 'page[number]' => '2', 'page[size]' => '2' })
        .to_return(status: 200, body: page_body(3,
          links_next: nil), headers: json_headers)
    end

    describe '.auto_paging_each' do
      it 'yields every record across all pages' do
        names = []
        klass.per(2).auto_paging_each { |w| names << w.name }
        expect(names).to eq(['Widget 1', 'Widget 2', 'Widget 3'])
      end

      it 'returns an Enumerator when called without a block' do
        expect(klass.per(2).auto_paging_each).to be_an(Enumerator)
      end

      it 'supports lazy chaining' do
        first_two = klass.per(2).auto_paging_each.lazy.first(2)
        expect(first_two.map(&:name)).to eq(['Widget 1', 'Widget 2'])
      end

      context 'when called directly on the class' do
        before do
          stub_request(:get, url)
            .with(query: { 'page[number]' => '1', 'page[size]' => '20' })
            .to_return(status: 200, body: page_body(1), headers: json_headers)
        end

        it 'uses the default page size of 20' do
          names = []
          klass.auto_paging_each { |w| names << w.name }
          expect(names).to eq(['Widget 1'])
        end

        it 'returns an Enumerator without a block' do
          expect(klass.auto_paging_each).to be_an(Enumerator)
        end
      end
    end

    describe '.each_page' do
      it 'yields each page as an Array of instances' do
        pages = []
        klass.per(2).each_page { |page| pages << page.map(&:name) }
        expect(pages).to eq([['Widget 1', 'Widget 2'], ['Widget 3']])
      end

      it 'returns an Enumerator when called without a block' do
        expect(klass.per(2).each_page).to be_an(Enumerator)
      end

      it 'returns instances of the resource class' do
        klass.per(2).each_page { |page| expect(page).to all(be_a(klass)) }
      end
    end

    describe '#auto_paging (QueryProxy)' do
      it 'returns an Enumerator over all records' do
        names = klass.per(2).auto_paging.map(&:name)
        expect(names).to eq(['Widget 1', 'Widget 2', 'Widget 3'])
      end

      it 'is composable with filter and order' do
        stub_request(:get, url)
          .with(query: { 'filter[status]' => 'active', 'page[number]' => '1',
                         'page[size]' => '2' })
          .to_return(status: 200, body: page_body(1), headers: json_headers)

        names = klass.filter(status: 'active').per(2).auto_paging.map(&:name)
        expect(names).to eq(['Widget 1'])
      end
    end

    context 'when the last page is exactly full and links.next is null' do
      before do
        stub_request(:get, url)
          .with(query: { 'page[number]' => '1', 'page[size]' => '3' })
          .to_return(status: 200, body: page_body(1, 2, 3, links_next: nil),
            headers: json_headers)
      end

      it 'does not fetch another page' do
        names = []
        klass.per(3).auto_paging_each { |w| names << w.name }
        expect(names).to eq(['Widget 1', 'Widget 2', 'Widget 3'])
        expect(WebMock).not_to have_requested(:get, url)
          .with(query: { 'page[number]' => '2', 'page[size]' => '3' })
      end
    end

    context 'when the API omits links (legacy heuristic)' do
      before do
        stub_request(:get, url)
          .with(query: { 'page[number]' => '1', 'page[size]' => '3' })
          .to_return(status: 200, body: page_body(1, 2, 3), headers: json_headers)
        stub_request(:get, url)
          .with(query: { 'page[number]' => '2', 'page[size]' => '3' })
          .to_return(status: 200, body: page_body, headers: json_headers)
      end

      it 'makes one extra request when the last page has exactly per items' do
        names = []
        klass.per(3).auto_paging_each { |w| names << w.name }
        expect(names).to eq(['Widget 1', 'Widget 2', 'Widget 3'])
        expect(WebMock).to have_requested(:get, url)
          .with(query: { 'page[number]' => '2', 'page[size]' => '3' })
      end
    end

    context 'when the API returns an error mid-pagination' do
      before do
        stub_request(:get, url)
          .with(query: { 'page[number]' => '1', 'page[size]' => '2' })
          .to_return(status: 200, body: page_body(1, 2), headers: json_headers)
        stub_request(:get, url)
          .with(query: { 'page[number]' => '2', 'page[size]' => '2' })
          .to_return(status: 500, body: { errors: [{ detail: 'server error' }] }.to_json,
            headers: json_headers)
      end

      it 'raises ServerError on the failing page' do
        expect do
          klass.per(2).auto_paging_each { |_| }
        end.to raise_error(Clicksign::ServerError)
      end
    end

    context 'when per is 0 (defensive: should not loop infinitely)' do
      before do
        body = {
          'data' => [{ 'id' => 'id-1', 'type' => 'widgets',
                       'attributes' => { 'name' => 'Widget 1' } }],
        }.to_json

        stub_request(:get, url)
          .with(query: { 'page[number]' => '1', 'page[size]' => '0' })
          .to_return(status: 200, body: body, headers: json_headers)
      end

      it 'stops after the first page and does not loop' do
        names = []
        klass.per(0).auto_paging_each { |w| names << w.name }
        expect(names).to eq(['Widget 1'])
        expect(WebMock).to have_requested(:get, url)
          .with(query: { 'page[number]' => '1', 'page[size]' => '0' }).once
      end
    end

    context 'when the API returns links: {} (present but without next key)' do
      before do
        body = {
          'data' => [{ 'id' => 'id-1', 'type' => 'widgets',
                       'attributes' => { 'name' => 'Widget 1' } }],
          'links' => {},
        }.to_json

        stub_request(:get, url)
          .with(query: { 'page[number]' => '1', 'page[size]' => '1' })
          .to_return(status: 200, body: body, headers: json_headers)
      end

      it 'stops pagination without fetching a second page' do
        names = []
        klass.per(1).auto_paging_each { |w| names << w.name }
        expect(names).to eq(['Widget 1'])
        expect(WebMock).not_to have_requested(:get, url)
          .with(query: { 'page[number]' => '2', 'page[size]' => '1' })
      end
    end
  end
end
