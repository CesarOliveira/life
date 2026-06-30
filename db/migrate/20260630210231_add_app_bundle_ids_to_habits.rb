class AddAppBundleIdsToHabits < ActiveRecord::Migration[8.1]
  def change
    add_column :habits, :app_bundle_ids, :string, array: true, default: [], null: false
  end
end
