# frozen_string_literal: true

# All phone operations use the phonelib gem only (libphonenumber data).
# Random numbers are generated then re-validated with Phonelib before use.
class PhonelibPhoneService
  class RandomGenerationError < StandardError; end

  # Raised for client input / validation issues. Carries optional field + stable code for API details[].
  class InvalidRequestError < StandardError
    attr_reader :field, :error_code

    def initialize(message, field: nil, error_code: "VALIDATION_ERROR")
      super(message)
      @field = field&.to_s
      @error_code = error_code.to_s.upcase
    end
  end

  MAX_GENERATION_ATTEMPTS = 2_000
  NATIONAL_DIGIT_BOUNDS = (7..12).freeze
  MUTATION_ATTEMPTS = 80
  BRUTE_INNER = 30

  class << self
    def random_valid
      MAX_GENERATION_ATTEMPTS.times do
        country = Phonelib.phone_data.keys.sample
        phone = build_valid_for_country(country)
        next if phone.nil?

        payload = verified_payload(phone)
        next unless payload

        # verified_payload already checks Phonelib; re-check E.164 before returning so only valid numbers exit the API.
        final = Phonelib.parse(payload[:phone].to_s)
        next unless final.valid? && Phonelib.valid?(final.sanitized)

        return payload
      end
      raise RandomGenerationError, "Could not generate a phonelib-verified number after #{MAX_GENERATION_ATTEMPTS} attempts"
    end

    def lookup(phone_str:, country_iso2:)
      normalized_country = normalize_country_code(country_iso2)
      input = phone_str.to_s.strip
      raise InvalidRequestError.new("phone is required", field: "phone", error_code: "PHONE_REQUIRED") if input.empty?

      phone = Phonelib.parse(input, normalized_country)
      unless phone.valid? && phone.valid_for_country?(normalized_country) && Phonelib.valid?(phone.sanitized)
        raise InvalidRequestError.new(
          "Not a valid phone number for the given country",
          field: "phone",
          error_code: "INVALID_PHONE_FOR_COUNTRY"
        )
      end

      unless phone.country == normalized_country
        raise InvalidRequestError.new(
          "Number does not belong to the specified country",
          field: "phone",
          error_code: "PHONE_COUNTRY_MISMATCH"
        )
      end

      verified_payload(phone) || raise(
        InvalidRequestError.new(
          "Number could not be re-verified by phonelib",
          field: "phone",
          error_code: "PHONE_VERIFICATION_FAILED"
        )
      )
    end

    def validate(national_or_full:, country_dialing_code:)
      dialing = country_dialing_code.to_s.strip.delete_prefix("+")
      raise InvalidRequestError.new(
        "country_code is required",
        field: "country_code",
        error_code: "COUNTRY_CODE_REQUIRED"
      ) if dialing.empty?

      raise InvalidRequestError.new(
        "phone is required",
        field: "phone",
        error_code: "PHONE_REQUIRED"
      ) if national_or_full.to_s.strip.empty?

      unless /\A\d+\z/.match?(dialing)
        raise InvalidRequestError.new(
          "country_code must contain digits only",
          field: "country_code",
          error_code: "INVALID_COUNTRY_CODE_FORMAT"
        )
      end

      national = national_or_full.to_s.strip.gsub(/\D/, "")
      if national.empty?
        raise InvalidRequestError.new(
          "phone must contain digits",
          field: "phone",
          error_code: "INVALID_PHONE_FORMAT"
        )
      end

      unless find_main_country_for_dialing(dialing)
        raise InvalidRequestError.new(
          "Unknown or ambiguous country_code (try ISO country on the lookup endpoint)",
          field: "country_code",
          error_code: "UNKNOWN_OR_AMBIGUOUS_COUNTRY_CODE"
        )
      end

      e164 = "+#{dialing}#{national}"
      phone = Phonelib.parse(e164)

      if phone.valid? && Phonelib.valid?(phone.sanitized) && phone.country_code == dialing
        {
          valid: true,
          **payload_from_phone(phone)
        }
      else
        {
          valid: false,
          reason: "Number is not a valid E.164 number for the given country code"
        }
      end
    end

    def verified_payload(phone)
      return nil unless phone.is_a?(Phonelib::Phone)

      e164 = phone.e164
      return nil if e164.blank?
      return nil unless Phonelib.valid?(phone.sanitized) && Phonelib.parse(e164).valid?

      payload_from_phone(Phonelib.parse(e164))
    end

    def payload_from_phone(phone)
      {
        phone: phone.e164,
        country_code: phone.country_code,
        country_name: phone.valid_country_name.presence || phone.country,
        short_country_name: phone.country
      }
    end

    private

    def normalize_country_code(country)
      c = country.to_s.strip.upcase
      unless /\A[A-Z]{2}\z/.match?(c)
        raise InvalidRequestError.new(
          "country must be a 2-letter ISO code",
          field: "country",
          error_code: "INVALID_COUNTRY_ISO_FORMAT"
        )
      end

      unless Phonelib.phone_data.key?(c)
        raise InvalidRequestError.new(
          "Unknown country",
          field: "country",
          error_code: "UNKNOWN_COUNTRY"
        )
      end

      c
    end

    def find_main_country_for_dialing(dialing)
      candidates = Phonelib.data_by_country_codes[dialing] || []
      if candidates.size == 1
        return candidates.first[:id]
      end

      # Prefer the record marked as main (e.g. +1 => US; still ambiguous for national parsing).
      main = candidates.find { |c| c[:main_country_for_code] == "true" }
      main&.fetch(:id, nil) || candidates.first&.fetch(:id, nil)
    end

    def build_valid_for_country(country)
      MUTATION_ATTEMPTS.times do
        phone = from_example_mutation(country)
        return phone if acceptable?(phone, country)
      end
      BRUTE_INNER.times do
        phone = from_random_national_length(country)
        return phone if acceptable?(phone, country)
      end
      nil
    end

    def from_example_mutation(country)
      data = Phonelib.phone_data[country]
      return nil unless data

      example =
        data.dig(:types, :mobile, :example_number) ||
        data.dig(:types, :fixed_line, :example_number) ||
        data.dig(:types, :toll_free, :example_number)
      return nil unless example

      len = example.length
      return nil if len < 4

      prefix_len = [ len - 4, 0 ].max
      prefix = example[0, prefix_len]
      suffix = SecureRandom.random_number(10**4).to_s.rjust(4, "0")
      candidate = "#{prefix}#{suffix}"
      candidate = candidate[0, len] if candidate.length > len

      Phonelib.parse(candidate, country)
    end

    def from_random_national_length(country)
      min_l, max_l = national_length_bounds(country)
      len = rand(min_l..max_l)
      national = (1..len).map { rand(0..9).to_s }.join
      # Avoid leading zero when lib expects non-zero; extra parse pass will still reject
      Phonelib.parse(national, country)
    end

    def national_length_bounds(country)
      p =
        Phonelib.phone_data[country]&.dig(:types, :mobile, :possible_number_pattern) ||
        Phonelib.phone_data[country]&.dig(:types, :fixed_line, :possible_number_pattern) ||
        Phonelib.phone_data[country]&.dig(:types, :general_desc, :possible_number_pattern)
      return [ NATIONAL_DIGIT_BOUNDS.begin, NATIONAL_DIGIT_BOUNDS.end ] if p.nil?

      matches = p.scan(/\\d\{(\d+)(?:,(\d+))?\}/).map do |a, b|
        if b
          [ a.to_i, b.to_i ]
        else
          n = a.to_i
          [ n, n ]
        end
      end
      return [ NATIONAL_DIGIT_BOUNDS.begin, NATIONAL_DIGIT_BOUNDS.end ] if matches.empty?

      min_m = matches.map(&:first).min
      max_m = matches.map { |a| a[1] }.max
      lo = [ min_m, NATIONAL_DIGIT_BOUNDS.begin ].max
      hi = [ max_m, NATIONAL_DIGIT_BOUNDS.end ].min
      return [ NATIONAL_DIGIT_BOUNDS.begin, NATIONAL_DIGIT_BOUNDS.end ] if lo > hi

      [ lo, hi ]
    end

    def acceptable?(phone, expected_country)
      return false unless phone.is_a?(Phonelib::Phone)
      return false unless phone.valid? && Phonelib.valid?(phone.sanitized)
      return false unless phone.country == expected_country

      true
    end
  end
end
