# frozen_string_literal: true

module Api
  module V1
    class PhonesController < BaseController
      # GET /api/v1/phones/random  (or GET /v1/phones/random)
      def random
        render_success data: PhonelibPhoneService.random_valid
      end
    end
  end
end
