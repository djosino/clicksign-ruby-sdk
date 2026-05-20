# frozen_string_literal: true

module Clicksign
  module Resources
    module AcceptanceTerm
      class Whatsapp < Clicksign::Resource
        self.resource_type = 'acceptance_term_whatsapps'
        self.endpoint      = '/acceptance_term/whatsapps'
      end
    end
  end
end
