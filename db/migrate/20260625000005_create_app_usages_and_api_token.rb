class CreateAppUsagesAndApiToken < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :api_token, :string
    add_index :accounts, :api_token, unique: true

    create_table :app_usages do |t|
      t.references :account, null: false, foreign_key: true
      t.string :device, null: false, default: "iphone"
      t.date :date, null: false
      t.string :bundle_id, null: false
      t.string :name
      t.integer :seconds, null: false, default: 0

      t.timestamps
    end

    add_index :app_usages, [:account_id, :device, :date, :bundle_id],
              unique: true, name: "idx_app_usages_unique"
  end
end
