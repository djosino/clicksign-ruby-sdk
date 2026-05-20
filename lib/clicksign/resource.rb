# frozen_string_literal: true

module Clicksign
  class Resource
    class QueryProxy
      include Enumerable

      def initialize(resource_class, builder)
        @resource_class = resource_class
        @builder        = builder
      end

      def filter(**params)
        @builder.filter(**params)
        self
      end

      def include(*types)
        @builder.include(*types)
        self
      end

      def order(field)
        @builder.order(field)
        self
      end

      def page(number)
        @builder.page(number)
        self
      end

      def per(size)
        @builder.per(size)
        self
      end

      def fields(**types)
        @builder.fields(**types)
        self
      end

      def to_a
        @resource_class.send(:fetch_list, @builder.to_params)
      end

      def first
        to_a.first
      end

      def last
        to_a.last
      end

      def count
        to_a.size
      end

      def each(&block)
        to_a.each(&block)
      end

      def auto_paging_each(&block)
        return enum_for(:auto_paging_each) unless block_given?

        @resource_class.send(:fetch_auto_pages, @builder.to_params) do |page|
          page.each(&block)
        end
      end

      def each_page(&block)
        return enum_for(:each_page) unless block_given?

        @resource_class.send(:fetch_auto_pages, @builder.to_params, &block)
      end

      def auto_paging
        enum_for(:auto_paging_each)
      end
    end

    class << self
      attr_writer :resource_type, :endpoint

      def resource_type
        @resource_type || infer_resource_type
      end

      def endpoint
        @endpoint || "/#{resource_type}"
      end

      def list(**filters)
        return fetch_list({}) if filters.empty?

        filter(**filters).to_a
      end

      def retrieve(id)
        raw    = client.get("#{endpoint}/#{id}")
        parsed = JsonApi::Parser.parse(raw)
        build_instance(parsed[:data].first)
      end

      def create(**attributes)
        relationships = attributes.delete(:relationships) || {}
        raw = client.post(
          endpoint,
          body: JsonApi::Serializer.dump(
            type: resource_type, attributes: attributes, relationships: relationships,
          ),
        )
        parsed = JsonApi::Parser.parse(raw)
        build_instance(parsed[:data].first)
      end

      def filter(**params)
        QueryProxy.new(self, JsonApi::QueryBuilder.new.filter(**params))
      end

      def include(*types)
        QueryProxy.new(self, JsonApi::QueryBuilder.new.include(*types))
      end

      def order(field)
        QueryProxy.new(self, JsonApi::QueryBuilder.new.order(field))
      end

      def page(number)
        QueryProxy.new(self, JsonApi::QueryBuilder.new.page(number))
      end

      def per(size)
        QueryProxy.new(self, JsonApi::QueryBuilder.new.per(size))
      end

      def fields(**types)
        QueryProxy.new(self, JsonApi::QueryBuilder.new.fields(**types))
      end

      def nested_list(parent_id, nested_type:, as: self, params: {})
        raw    = client.get("#{endpoint}/#{parent_id}/#{nested_type}", params: params)
        parsed = JsonApi::Parser.parse(raw)
        parsed[:data].map { |item| as.send(:build_instance, item, parent_id: parent_id) }
      end

      def filter_params(**filters)
        filters.empty? ? {} : JsonApi::QueryBuilder.new.filter(**filters).to_params
      end

      def auto_paging_each(&block)
        return enum_for(:auto_paging_each) unless block_given?

        fetch_auto_pages({}) { |page| page.each(&block) }
      end

      def each_page(&block)
        return enum_for(:each_page) unless block_given?

        fetch_auto_pages({}, &block)
      end

      def client
        Thread.current[:clicksign_client] || Clicksign.client
      end

      private

      def fetch_list(params)
        raw    = client.get(endpoint, params: params)
        parsed = JsonApi::Parser.parse(raw)
        parsed[:data].map { |item| build_instance(item) }
      end

      def fetch_auto_pages(params)
        per  = (params['page[size]'] || 20).to_i
        base = params.except('page[number]')
        page = 1

        loop do
          raw   = client.get(endpoint,
                             params: base.merge('page[number]' => page,
                                                'page[size]' => per))
          items = JsonApi::Parser.parse(raw)[:data].map { |item| build_instance(item) }
          yield items
          break if items.size < per

          page += 1
        end
      end

      def build_instance(data, parent_id: nil)
        instance = allocate
        instance.send(:load_data, data, parent_id: parent_id)
        instance
      end

      def infer_resource_type
        "#{name.split('::').last
              .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
              .gsub(/([a-z\d])([A-Z])/, '\1_\2')
              .downcase}s"
      end
    end

    attr_reader :id, :relationships

    def update(**attributes)
      raw = self.class.client.patch(
        "#{base_path}/#{@id}",
        body: JsonApi::Serializer.dump(
          type: self.class.resource_type, id: @id, attributes: attributes,
        ),
      )
      parsed = JsonApi::Parser.parse(raw)
      load_data(parsed[:data].first, parent_id: @_parent_id)
      self
    end

    def delete
      self.class.client.delete("#{base_path}/#{@id}")
      nil
    end

    def reload
      raw    = self.class.client.get("#{base_path}/#{@id}")
      parsed = JsonApi::Parser.parse(raw)
      load_data(parsed[:data].first, parent_id: @_parent_id)
      self
    end

    def base_path
      self.class.endpoint
    end

    def [](key)
      @_attributes&.[](key.to_s)
    end

    def method_missing(name, *args, &block)
      key = name.to_s.delete_suffix('=')
      if @_attributes&.key?(key)
        name.to_s.end_with?('=') ? @_attributes[key] = args.first : @_attributes[key]
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      key = name.to_s.delete_suffix('=')
      @_attributes&.key?(key) || super
    end

    private

    def load_data(data, parent_id: nil)
      @id            = data['id']
      @relationships = data['relationships'] || {}
      @_attributes   = data['attributes'] || {}
      @_parent_id    = parent_id
    end
  end
end
