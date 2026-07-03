# Categorias de hábitos por conta (até 10) — alimentam o radar de atividade.
# Cria a tabela, o vínculo em habits e semeia as 4 categorias padrão em cada
# conta existente (novas contas ganham as padrão via callback no Account).
class CreateHabitCategories < ActiveRecord::Migration[8.1]
  DEFAULTS = %w[Saúde Performance Mente Relacionamentos].freeze

  class MigAccount < ActiveRecord::Base
    self.table_name = "accounts"
  end

  class MigCategory < ActiveRecord::Base
    self.table_name = "habit_categories"
  end

  def up
    create_table :habit_categories do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
      t.index [:account_id, :name], unique: true
    end

    add_reference :habits, :habit_category, foreign_key: true

    MigAccount.pluck(:id).each do |account_id|
      DEFAULTS.each_with_index do |name, i|
        MigCategory.create!(account_id: account_id, name: name, position: i)
      end
    end
  end

  def down
    remove_reference :habits, :habit_category
    drop_table :habit_categories
  end
end
