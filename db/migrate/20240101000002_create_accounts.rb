class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :join_code
      t.bigint :owner_id
      t.timestamps
    end

    add_index :accounts, :join_code, unique: true
    add_index :accounts, :owner_id
    add_foreign_key :accounts, :users, column: :owner_id
  end
end
