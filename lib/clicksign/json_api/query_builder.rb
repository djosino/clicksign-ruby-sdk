# frozen_string_literal: true

module Clicksign
  module JsonApi
    class QueryBuilder
      def initialize
        @params = {}
      end

      def filter(**filters)
        filters.each { |k, v| @params["filter[#{k}]"] = v }
        self
      end

      def include(*types)
        existing = @params['include']&.split(',') || []
        @params['include'] = (existing + types.map(&:to_s)).uniq.join(',')
        self
      end

      def order(field)
        @params['sort'] = field.to_s
        self
      end

      def page(number)
        @params['page[number]'] = number
        self
      end

      def per(size)
        @params['page[size]'] = size
        self
      end

      def fields(**types)
        types.each { |type, list| @params["fields[#{type}]"] = Array(list).join(',') }
        self
      end

      def to_params
        @params.dup
      end
    end
  end
end
