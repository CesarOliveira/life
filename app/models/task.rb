# == Schema Information
#
# Table name: tasks
#
#  id             :bigint           not null, primary key
#  completed_at   :datetime
#  description    :text
#  due_on         :date
#  number         :integer          not null
#  position       :integer          default(0), not null
#  title          :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#  creator_id     :bigint
#  external_id    :string
#  task_board_id  :bigint           not null
#  task_column_id :bigint           not null
#
# Indexes
#
#  index_tasks_on_account_id                   (account_id)
#  index_tasks_on_account_id_and_external_id   (account_id,external_id) UNIQUE WHERE (external_id IS NOT NULL)
#  index_tasks_on_account_id_and_number        (account_id,number) UNIQUE
#  index_tasks_on_creator_id                   (creator_id)
#  index_tasks_on_task_board_id                (task_board_id)
#  index_tasks_on_task_column_id               (task_column_id)
#  index_tasks_on_task_column_id_and_position  (task_column_id,position)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (task_board_id => task_boards.id)
#  fk_rails_...  (task_column_id => task_columns.id)
#
class Task < ApplicationRecord
  belongs_to :account
  belongs_to :task_board
  belongs_to :task_column
  belongs_to :creator, class_name: "User", optional: true
  has_many :comments, -> { order(:created_at, :id) }, class_name: "TaskComment", dependent: :destroy, inverse_of: :task

  validates :title, presence: true, length: { maximum: 200 }
  validates :number, presence: true, uniqueness: { scope: :account_id }
  validate :column_belongs_to_board

  before_validation :assign_number, on: :create
  before_validation :assign_position, on: :create

  def done?
    completed_at.present?
  end

  def overdue?
    due_on.present? && !done? && due_on < Date.current
  end

  private

  def assign_number
    self.number ||= account.tasks.maximum(:number).to_i + 1 if account
  end

  def assign_position
    self.position = task_column.tasks.maximum(:position).to_i + 1 if task_column && position.to_i.zero?
  end

  def column_belongs_to_board
    return if task_column.nil? || task_column.task_board_id == task_board_id

    errors.add(:task_column, :invalid)
  end
end
