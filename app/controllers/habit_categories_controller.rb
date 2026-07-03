# CRUD das categorias de hábitos (até 10 por conta) — gerido nas configurações
# da conta.
class HabitCategoriesController < ApplicationController
  def create
    category = current_account.habit_categories.new(category_params)
    category.position = current_account.habit_categories.maximum(:position).to_i + 1
    if category.save
      redirect_to edit_account_path(current_account), notice: t("categories.saved")
    else
      redirect_to edit_account_path(current_account), alert: category.errors.full_messages.to_sentence
    end
  end

  def update
    category = current_account.habit_categories.find(params[:id])
    if category.update(category_params)
      redirect_to edit_account_path(current_account), notice: t("categories.saved")
    else
      redirect_to edit_account_path(current_account), alert: category.errors.full_messages.to_sentence
    end
  end

  def destroy
    category = current_account.habit_categories.find(params[:id])
    category.destroy
    redirect_to edit_account_path(current_account), notice: t("categories.removed")
  end

  private

  def category_params
    params.require(:habit_category).permit(:name)
  end
end
