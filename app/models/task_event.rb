# == Schema Information
#
# Table name: task_events
#
#  id          :bigint           not null, primary key
#  from_column :string
#  kind        :string           not null
#  occurred_at :datetime         not null
#  to_column   :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  task_id     :bigint           not null
#  user_id     :bigint
#
# Indexes
#
#  index_task_events_on_task_id                  (task_id)
#  index_task_events_on_task_id_and_occurred_at  (task_id,occurred_at)
#  index_task_events_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (task_id => tasks.id)
#  fk_rails_...  (user_id => users.id)
#
class TaskEvent < ApplicationRecord
  KINDS = %w[created moved].freeze

  belongs_to :task
  belongs_to :user, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :occurred_at, presence: true
end
