# frozen_string_literal: true

module Clicksign
  module JsonApi
    class Operations
      def initialize
        @entries = []
      end

      def add(data:)
        @entries << { 'op' => 'add', 'data' => stringify(data) }
        self
      end

      def remove(ref:)
        @entries << { 'op' => 'remove', 'ref' => stringify(ref) }
        self
      end

      def to_h
        { 'atomic:operations' => @entries }
      end

      attr_reader :entries

      private

      def stringify(value)
        case value
        when Hash then value.transform_keys(&:to_s).transform_values { |v| stringify(v) }
        when Array then value.map { |v| stringify(v) }
        when Symbol then value.to_s
        else value
        end
      end
    end
  end
end
