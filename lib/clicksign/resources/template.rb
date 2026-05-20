# frozen_string_literal: true

module Clicksign
  module Resources
    class Template < Clicksign::Resource
      self.resource_type = 'templates'

      def self.list_template_fields(template_id)
        nested_list(template_id, nested_type: 'template_fields', as: TemplateField)
      end
    end
  end
end
