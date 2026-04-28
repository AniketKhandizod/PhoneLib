# frozen_string_literal: true

# Validates and parses raw JSON POST bodies for StoredPayload#create.
class StoredPayloadStore
  class InvalidPayloadError < StandardError
    attr_reader :code

    def initialize(message, code: "INVALID_PAYLOAD")
      super(message)
      @code = code
    end
  end

  class << self
    def decode_raw_body!(body_str)
      if body_str.bytesize > StoredPayload::MAX_BODY_BYTES
        raise InvalidPayloadError.new(
          "Payload exceeds maximum size of #{StoredPayload::MAX_BODY_BYTES} bytes",
          code: "PAYLOAD_TOO_LARGE"
        )
      end

      if body_str.strip.empty?
        raise InvalidPayloadError.new(
          "Request body cannot be empty; send JSON (object, array, string, number, boolean, or null).",
          code: "EMPTY_BODY"
        )
      end

      begin
        parsed = ActiveSupport::JSON.decode(body_str)
      rescue JSON::ParserError, ArgumentError => e
        raise InvalidPayloadError.new(
          "Body is not valid JSON: #{e.message}",
          code: "INVALID_JSON"
        )
      end

      parsed
    rescue InvalidPayloadError
      raise
    end
  end
end
