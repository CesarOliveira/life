class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user,    null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :role,   null: false, default: "member"
      t.string :status, null: false, default: "pending"
      t.timestamps
    end

    add_index :memberships, [:user_id, :account_id], unique: true
    add_index :memberships, :status
  end
end
