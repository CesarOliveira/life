# == Schema Information
#
# Table name: task_comments
#
#  id         :bigint           not null, primary key
#  body       :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  task_id    :bigint           not null
#  user_id    :bigint
#
# Indexes
#
#  index_task_comments_on_task_id  (task_id)
#  index_task_comments_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (task_id => tasks.id)
#  fk_rails_...  (user_id => users.id)
#
class TaskComment < ApplicationRecord
  belongs_to :task
  belongs_to :user, optional: true

  validates :body, presence: true, length: { maximum: 5000 }
end
