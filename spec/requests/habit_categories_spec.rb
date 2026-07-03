require "rails_helper"

RSpec.describe "HabitCategories", type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }

  before do
    create(:membership, user: user, account: account, role: "owner", status: "active")
    sign_in user
  end

  it "seeds the 4 default categories on account creation" do
    expect(account.habit_categories.ordered.pluck(:name))
      .to eq(%w[Saúde Performance Mente Relacionamentos])
  end

  it "creates, renames and removes a category" do
    post habit_categories_path, params: { habit_category: { name: "Finanças" } }
    cat = account.habit_categories.find_by(name: "Finanças")
    expect(cat).to be_present

    patch habit_category_path(cat), params: { habit_category: { name: "Grana" } }
    expect(cat.reload.name).to eq("Grana")

    delete habit_category_path(cat)
    expect(account.habit_categories.exists?(cat.id)).to be(false)
  end

  it "enforces the limit of 10 per account" do
    6.times { |i| account.habit_categories.create!(name: "Extra #{i}") } # 4 + 6 = 10
    post habit_categories_path, params: { habit_category: { name: "Estouro" } }
    expect(account.habit_categories.count).to eq(10)
  end

  it "assigns a category to a habit and nullifies on category removal" do
    cat = account.habit_categories.first
    habit = create(:habit, account: account, habit_category: cat)
    cat.destroy
    expect(habit.reload.habit_category).to be_nil
  end
end
