# frozen_string_literal: true

RSpec.describe Clicksign::JsonApi::QueryBuilder do
  subject(:builder) { described_class.new }

  describe '#filter' do
    it 'converts symbol keys to filter[key] format' do
      builder.filter(status: 'draft', locale: 'pt-BR')
      expect(builder.to_params).to eq('filter[status]' => 'draft',
                                      'filter[locale]' => 'pt-BR')
    end

    it 'returns self for chaining' do
      expect(builder.filter(status: 'draft')).to be(builder)
    end
  end

  describe '#include' do
    it 'joins multiple types with comma' do
      builder.include('folder', 'signers')
      expect(builder.to_params).to eq('include' => 'folder,signers')
    end

    it 'handles a single type' do
      builder.include('folder')
      expect(builder.to_params).to eq('include' => 'folder')
    end

    it 'returns self for chaining' do
      expect(builder.include('folder')).to be(builder)
    end
  end

  describe '#order' do
    it 'sets the sort param' do
      builder.order('name')
      expect(builder.to_params).to eq('sort' => 'name')
    end

    it 'accepts descending order with dash prefix' do
      builder.order('-created')
      expect(builder.to_params).to eq('sort' => '-created')
    end

    it 'converts symbol to string' do
      builder.order(:name)
      expect(builder.to_params).to eq('sort' => 'name')
    end

    it 'returns self for chaining' do
      expect(builder.order('name')).to be(builder)
    end
  end

  describe '#page' do
    it 'sets page[number]' do
      builder.page(2)
      expect(builder.to_params).to eq('page[number]' => 2)
    end

    it 'returns self for chaining' do
      expect(builder.page(1)).to be(builder)
    end
  end

  describe '#per' do
    it 'sets page[size]' do
      builder.per(50)
      expect(builder.to_params).to eq('page[size]' => 50)
    end

    it 'returns self for chaining' do
      expect(builder.per(10)).to be(builder)
    end
  end

  describe '#fields' do
    it 'sets fields[type] with comma-joined list' do
      builder.fields(envelopes: %w[name status])
      expect(builder.to_params).to eq('fields[envelopes]' => 'name,status')
    end

    it 'handles multiple resource types' do
      builder.fields(envelopes: %w[name], signers: %w[email])
      params = builder.to_params
      expect(params['fields[envelopes]']).to eq('name')
      expect(params['fields[signers]']).to eq('email')
    end

    it 'returns self for chaining' do
      expect(builder.fields(envelopes: ['name'])).to be(builder)
    end
  end

  describe '#to_params' do
    it 'returns a dup so mutations do not affect the builder' do
      builder.filter(status: 'draft')
      params = builder.to_params
      params['injected'] = 'value'
      expect(builder.to_params).not_to have_key('injected')
    end

    it 'returns empty hash when no params set' do
      expect(builder.to_params).to eq({})
    end
  end

  describe 'chaining all methods' do
    it 'accumulates params from every method' do
      params = builder
               .filter(status: 'draft')
               .include('folder')
               .order('-created')
               .page(1)
               .per(20)
               .fields(envelopes: %w[name status])
               .to_params

      expect(params).to eq(
        'filter[status]' => 'draft',
        'include' => 'folder',
        'sort' => '-created',
        'page[number]' => 1,
        'page[size]' => 20,
        'fields[envelopes]' => 'name,status',
      )
    end
  end
end
