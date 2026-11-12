# == Schema Information
#
# Table name: task_columns
#
#  id            :bigint           not null, primary key
#  color         :string           default("slate"), not null
#  done          :boolean          default(FALSE), not null
#  name          :string           not null
#  position      :integer          default(0), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  task_board_id :bigint           not null
#
# Indexes
#
#  index_task_columns_on_task_board_id  (task_board_id)
#
# Foreign Keys
#
#  fk_rails_...  (task_board_id => task_boards.id)
#
class TaskColumn < ApplicationRecord
  COLORS = %w[slate sky amber emerald rose violet].freeze

  belongs_to :task_board
  has_many :tasks, -> { order(:position, :id) }, dependent: :restrict_with_error, inverse_of: :task_column

  validates :name, presence: true, length: { maximum: 40 }
  validates :color, inclusion: { in: COLORS }
end
