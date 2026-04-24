# frozen_string_literal: true

module Api
  module V1
    class PhonesController < BaseController
      # GET /api/v1/phones/random
      def random
        render json: PhonelibPhoneService.random_valid
      end

      # GET /api/v1/phones/lookup?phone=&country=
      def lookup
        render json: PhonelibPhoneService.lookup(
          phone_str: params.require(:phone),
          country_iso2: params.require(:country)
        )
      end

      # POST /api/v1/phones/validate
      # JSON: { "phone": "7972708841", "country_code": "91" }
      def validate
        p = validate_params
        render json: PhonelibPhoneService.validate(
          national_or_full: p[:phone],
          country_dialing_code: p[:country_code]
        )
      end

      private

      def validate_params
        p = params.permit(:phone, :country_code)
        p.require(:phone)
        p.require(:country_code)
        p
      end
    end
  end
end
