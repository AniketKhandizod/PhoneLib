# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include ApiRenderable
      include BearerAuthenticatable

      rescue_from PhonelibPhoneService::InvalidRequestError, with: :render_invalid_request
      rescue_from PhonelibPhoneService::RandomGenerationError, with: :render_generation_failed
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
      rescue_from ActionDispatch::Http::Parameters::ParseError, with: :render_parse_error
      rescue_from ActionController::BadRequest, with: :render_bad_request

      rescue_from StandardError, with: :render_unexpected_error

      private

      def render_invalid_request(exception)
        detail = {
          code: exception.error_code,
          message: exception.message
        }
        detail[:field] = exception.field if exception.field.present?

        render_error(
          code: "VALIDATION_ERROR",
          message: exception.message,
          status: :unprocessable_entity,
          details: [ detail ],
          hint: "Fix the inputs listed in error.details and retry."
        )
      end

      def render_generation_failed(exception)
        render_error(
          code: "GENERATION_FAILED",
          message: exception.message,
          status: :service_unavailable,
          hint: "Retry shortly. If it continues, contact support with meta.request_id."
        )
      end

      def render_parameter_missing(exception)
        name = exception.param.to_s
        render_error(
          code: "MISSING_PARAMETER",
          message: "Required parameter is missing: #{name}",
          status: :bad_request,
          details: [
            {
              field: name,
              code: "REQUIRED",
              message: "This parameter is required for this operation."
            }
          ],
          hint: "Send the field in the query string (GET) or JSON body (POST) as documented."
        )
      end

      def render_parse_error(exception)
        render_error(
          code: "INVALID_JSON",
          message: "Request body could not be parsed as JSON.",
          status: :bad_request,
          details: [ { message: exception.message.to_s } ],
          hint: "Use Content-Type: application/json and valid JSON (double-quoted keys, no trailing commas)."
        )
      end

      def render_bad_request(exception)
        render_error(
          code: "BAD_REQUEST",
          message: exception.message.to_s,
          status: :bad_request
        )
      end

      def render_unexpected_error(exception)
        raise exception if Rails.application.config.consider_all_requests_local

        Rails.logger.error("[#{exception.class}] #{exception.message}\n#{exception.backtrace&.first(20)&.join("\n")}")
        render_error(
          code: "INTERNAL_ERROR",
          message: "An unexpected error occurred.",
          status: :internal_server_error,
          hint: "Include meta.request_id when contacting support."
        )
      end
    end
  end
end
