# 1) Conta ganha `locale` (pergunta do cadastro; define o idioma das categorias
#    padrão e da interface). 2) Hábito passa a EXIGIR categoria: faz backfill
#    dos existentes (primeira categoria da conta) e trava NOT NULL.
class RequireHabitCategoryAndAccountLocale < ActiveRecord::Migration[8.1]
  class MigCategory < ActiveRecord::Base
    self.table_name = "habit_categories"
  end

  class MigHabit < ActiveRecord::Base
    self.table_name = "habits"
  end

  def up
    add_column :accounts, :locale, :string, null: false, default: "pt-BR"

    MigHabit.where(habit_category_id: nil).find_each do |habit|
      category = MigCategory.where(account_id: habit.account_id).order(:position, :id).first
      category ||= MigCategory.create!(account_id: habit.account_id, name: "Saúde", position: 0)
      habit.update_columns(habit_category_id: category.id)
    end

    change_column_null :habits, :habit_category_id, false
  end

  def down
    change_column_null :habits, :habit_category_id, true
    remove_column :accounts, :locale
  end
end
