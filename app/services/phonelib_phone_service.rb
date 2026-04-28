# frozen_string_literal: true

# Random E.164 numbers using the phonelib gem (libphonenumber). Each candidate is verified with Phonelib
# before it is returned; only valid numbers are exposed.
class PhonelibPhoneService
  class RandomGenerationError < StandardError; end

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

        final = Phonelib.parse(payload[:phone_number].to_s)
        next unless final.valid? && Phonelib.valid?(final.sanitized)

        return payload
      end
      raise RandomGenerationError, "Could not generate a phonelib-verified number after #{MAX_GENERATION_ATTEMPTS} attempts"
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
        phone_number: phone.e164,
        country_code: phone.country_code,
        country_name: phone.valid_country_name.presence || phone.country
      }
    end

    private

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
