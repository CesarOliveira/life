class AddFavoriteToExamGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :exam_groups, :favorite, :boolean, default: false, null: false
  end
end
