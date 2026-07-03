# Move o hábito "Tempo de Tela" para a categoria Performance (pedido do dono;
# idempotente e seguro em qualquer conta que tenha ambos).
class MoveScreenTimeHabitToPerformance < ActiveRecord::Migration[8.1]
  class MigHabit < ActiveRecord::Base
    self.table_name = "habits"
  end

  class MigCategory < ActiveRecord::Base
    self.table_name = "habit_categories"
  end

  def up
    MigHabit.where("LOWER(name) = ?", "tempo de tela").find_each do |habit|
      performance = MigCategory.where(account_id: habit.account_id)
                               .where("LOWER(name) = ?", "performance").first
      habit.update_columns(habit_category_id: performance.id) if performance
    end
  end

  def down; end
end
