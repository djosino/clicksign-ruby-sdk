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

  describe 'auto-pagination' do
    include_context 'with clicksign configured'

    let(:url)          { "#{JsonApiFixtures::BASE_URL}/widgets" }
    let(:json_headers) { { 'Content-Type' => 'application/vnd.api+json' } }

    def page_body(*ids)
      { 'data' => ids.map do |n|
        { 'id' => "id-#{n}", 'type' => 'widgets',
          'attributes' => { 'name' => "Widget #{n}" } }
      end }.to_json
    end

    before do
      stub_request(:get, url)
        .with(query: { 'page[number]' => '1', 'page[size]' => '2' })
        .to_return(status: 200, body: page_body(1, 2), headers: json_headers)
      stub_request(:get, url)
        .with(query: { 'page[number]' => '2', 'page[size]' => '2' })
        .to_return(status: 200, body: page_body(3), headers: json_headers)
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

    context 'when the last page is exactly full' do
      before do
        stub_request(:get, url)
          .with(query: { 'page[number]' => '1', 'page[size]' => '3' })
          .to_return(status: 200, body: page_body(1, 2, 3), headers: json_headers)
        stub_request(:get, url)
          .with(query: { 'page[number]' => '2', 'page[size]' => '3' })
          .to_return(status: 200, body: page_body, headers: json_headers)
      end

      it 'makes one extra request to confirm exhaustion' do
        names = []
        klass.per(3).auto_paging_each { |w| names << w.name }
        expect(names).to eq(['Widget 1', 'Widget 2', 'Widget 3'])
        expect(WebMock).to have_requested(:get, url)
          .with(query: { 'page[number]' => '2', 'page[size]' => '3' })
      end
    end
  end
end
