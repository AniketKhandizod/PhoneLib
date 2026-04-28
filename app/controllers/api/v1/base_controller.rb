# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include ApiRenderable

      rescue_from PhonelibPhoneService::RandomGenerationError, with: :render_generation_failed
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
      rescue_from ActionDispatch::Http::Parameters::ParseError, with: :render_parse_error
      rescue_from ActionController::BadRequest, with: :render_bad_request

      rescue_from StandardError, with: :render_unexpected_error

      private

      def render_generation_failed(exception)
        render_error(
          code: "GENERATION_FAILED",
          message: "Random number generation failed: #{exception.message}. " \
                   "The service could not produce a Phonelib-valid E.164 number in time.",
          status: :service_unavailable,
          hint: "Retry later. If this persists, report with meta.request_id; the generator may be under load."
        )
      end

      def render_parameter_missing(exception)
        name = exception.param.to_s
        render_error(
          code: "MISSING_PARAMETER",
          message: "Bad request: required parameter '#{name}' was not sent. " \
                   "Rails reported: #{exception.message}",
          status: :bad_request,
          details: [
            {
              field: name,
              code: "REQUIRED",
              message: "This parameter must be present for this endpoint (query string for GET, JSON for POST)."
            }
          ],
          hint: "This API only exposes GET /api/v1/phones/random (no required query parameters)."
        )
      end

      def render_parse_error(exception)
        render_error(
          code: "INVALID_JSON",
          message: "JSON parse failed: #{exception.message.to_s.truncate(400)}",
          status: :bad_request,
          details: [ { message: exception.message.to_s } ],
          hint: "This service is GET-only; you should not need a JSON body for the phone random endpoint."
        )
      end

      def render_bad_request(exception)
        render_error(
          code: "BAD_REQUEST",
          message: "Bad request: #{exception.message.to_s.truncate(500)}",
          status: :bad_request,
          hint: "The request format or parameters were rejected before reaching business logic."
        )
      end

      def render_unexpected_error(exception)
        raise exception if Rails.application.config.consider_all_requests_local

        Rails.logger.error("[#{exception.class}] #{exception.message}\n#{exception.backtrace&.first(20)&.join("\n")}")
        render_error(
          code: "INTERNAL_ERROR",
          message: "Unexpected error (#{exception.class.name}): #{exception.message.to_s.truncate(400)}",
          status: :internal_server_error,
          hint: "See message for the exception class and server message. Include meta.request_id for support."
        )
      end
    end
  end
end
