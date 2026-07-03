# == Schema Information
#
# Table name: habits
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  app_bundle_ids    :string           default([]), not null, is an Array
#  auto              :boolean          default(FALSE), not null
#  color             :string           default("#6366f1"), not null
#  comparator        :string
#  description       :text
#  frequency         :string           default("weekly_days"), not null
#  metric_key        :string
#  name              :string           not null
#  position          :integer          default(0), not null
#  threshold_value   :decimal(12, 3)
#  weekdays          :integer          default([0, 1, 2, 3, 4, 5, 6]), not null, is an Array
#  weekly_target     :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  habit_category_id :bigint           not null
#
# Indexes
#
#  index_habits_on_account_id             (account_id)
#  index_habits_on_account_id_and_active  (account_id,active)
#  index_habits_on_habit_category_id      (habit_category_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (habit_category_id => habit_categories.id)
#
FactoryBot.define do
  factory :habit do
    association :account
    habit_category { account.habit_categories.ordered.first || association(:habit_category, account: account) }
    sequence(:name) { |n| "Hábito #{n}" }
    color { Habit::DEFAULT_COLOR }
    frequency { "weekly_days" }
    weekdays { Habit::WEEKDAYS }
    active { true }

    trait :weekly_count do
      frequency { "weekly_count" }
      weekly_target { 3 }
    end

    trait :auto_screen_time do
      auto { true }
      metric_key { "screen_time_total" }
      comparator { "lte" }
      threshold_value { 3 }
    end
  end
end
