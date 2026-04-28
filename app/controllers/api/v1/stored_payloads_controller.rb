# frozen_string_literal: true

module Api
  module V1
    class StoredPayloadsController < BaseController
      # POST /api/v1/stored_payloads — arbitrary JSON body; returns sequential index (id).
      def create
        unless json_content_type?
          return render_error(
            code: "UNSUPPORTED_MEDIA_TYPE",
            message: "Use Content-Type: application/json for this endpoint.",
            status: 415,
            hint: "Example: curl -H \"Content-Type: application/json\" -d '{\"a\":1}' ..."
          )
        end

        parsed = StoredPayloadStore.decode_raw_body!(request.raw_post.to_s)
        norm = safe_as_json(parsed)

        record = StoredPayload.create!(payload_json: norm)

        render_success(data: { index: record.id })
      rescue ActiveRecord::RecordInvalid => e
        render_error(
          code: "DATABASE_ERROR",
          message: "Could not store payload: #{e.record.errors.full_messages.join(', ')}.",
          status: :unprocessable_entity,
          hint: "Ensure the body is JSON-compatible (object, array, string, number, boolean, null)."
        )
      end

      # GET /api/v1/stored_payloads/:index
      def show
        idx = validate_index_param(params[:index])
        return if idx.nil?

        record = StoredPayload.find_by(id: idx)
        unless record
          return render_error(
            code: "NOT_FOUND",
            message: "No stored payload exists for index #{idx}.",
            status: :not_found,
            details: [ { index: idx } ],
            hint: "POST to /api/v1/stored_payloads first to create an index, then GET that index."
          )
        end

        render_success(data: show_payload(record))
      end

      # GET /api/v1/stored_payloads/latest_index
      def latest_index
        render_success(data: { latest_index: StoredPayload.maximum(:id) })
      end

      private

      def json_content_type?
        ct = request.content_type.to_s.downcase
        ct.start_with?("application/json") || ct.end_with?("+json")
      end

      def safe_as_json(value)
        value.as_json
      rescue StandardError => e
        raise StoredPayloadStore::InvalidPayloadError, "Payload cannot be normalized for storage: #{e.message}"
      end

      def validate_index_param(raw)
        return invalid_index("index is required") unless raw.present?

        n = Integer(raw, exception: false)
        unless n.is_a?(Integer) && n.positive?
          return invalid_index("index must be a positive integer")
        end

        n
      end

      def invalid_index(msg)
        render_error(
          code: "INVALID_INDEX",
          message: msg,
          status: :bad_request,
          hint: "Use GET /api/v1/stored_payloads/1 (positive integer path segment)."
        )
        nil
      end

      def show_payload(record)
        {
          index: record.id,
          payload: record.payload_json,
          created_at: record.created_at&.iso8601(3),
          updated_at: record.updated_at&.iso8601(3)
        }
      end

    end
  end
end
