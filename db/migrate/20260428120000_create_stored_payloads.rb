# frozen_string_literal: true

class CreateStoredPayloads < ActiveRecord::Migration[8.0]
  def change
    create_table :stored_payloads do |t|
      # Column name "payload_json" avoids clashing with AR internal `payload`.
      t.json :payload_json, null: true

      t.timestamps
    end
  end
end
