# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include BearerAuthenticatable

      rescue_from PhonelibPhoneService::InvalidRequestError do |e|
        render json: { error: { code: "invalid_request", message: e.message } }, status: :unprocessable_entity
      end

      rescue_from PhonelibPhoneService::RandomGenerationError do |e|
        render json: { error: { code: "generation_failed", message: e.message } }, status: :service_unavailable
      end

      rescue_from ActionController::ParameterMissing do |e|
        render json: { error: { code: "invalid_request", message: e.message } }, status: :bad_request
      end
    end
  end
end
