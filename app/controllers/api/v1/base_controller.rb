# frozen_string_literal: true

module Api
  module V1
    class BaseController < ApplicationController
      include ApiRenderable

      rescue_from PhonelibPhoneService::InvalidRequestError, with: :render_invalid_request
      rescue_from PhonelibPhoneService::RandomGenerationError, with: :render_generation_failed
      rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
      rescue_from ActionDispatch::Http::Parameters::ParseError, with: :render_parse_error
      rescue_from ActionController::BadRequest, with: :render_bad_request

      rescue_from StandardError, with: :render_unexpected_error

      private

      def render_invalid_request(exception)
        field_ctx = exception.field.present? ? " (field: #{exception.field})" : ""
        detail = {
          code: exception.error_code,
          message: exception.message
        }
        detail[:field] = exception.field if exception.field.present?

        render_error(
          code: "VALIDATION_ERROR",
          message: "#{exception.message}#{field_ctx} [code: #{exception.error_code}]",
          status: :unprocessable_entity,
          details: [ detail ],
          hint: "The request was rejected because input did not pass Phonelib validation rules. " \
                "See error.details for the field and stable error_code."
        )
      end

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
          hint: "lookup needs ?phone=…&country=… ; validate needs JSON keys phone and country_code."
        )
      end

      def render_parse_error(exception)
        render_error(
          code: "INVALID_JSON",
          message: "JSON parse failed: #{exception.message.to_s.truncate(400)}",
          status: :bad_request,
          details: [ { message: exception.message.to_s } ],
          hint: "Send Content-Type: application/json with syntactically valid JSON (double-quoted keys, matching braces)."
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
