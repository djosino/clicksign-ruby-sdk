# frozen_string_literal: true

module Clicksign
  module Resources
    module AutoSignature
      class Term < Clicksign::Resource
        self.resource_type = 'auto_signature_terms'
        self.endpoint      = '/auto_signature/terms'
      end
    end
  end
end
