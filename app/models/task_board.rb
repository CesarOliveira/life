# == Schema Information
#
# Table name: task_boards
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_task_boards_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class TaskBoard < ApplicationRecord
  # Sugestão inicial de colunas de um quadro novo (tudo editável depois).
  DEFAULT_COLUMNS = [
    { name_key: "todo", color: "slate" },
    { name_key: "doing", color: "sky" },
    { name_key: "qa", color: "amber" },
    { name_key: "done", color: "emerald", done: true }
  ].freeze

  belongs_to :account
  # A ordem importa na exclusão: as tarefas saem antes das colunas, porque uma
  # coluna com tarefas recusa ser apagada.
  has_many :tasks, dependent: :destroy
  has_many :columns, -> { order(:position, :id) }, class_name: "TaskColumn", dependent: :destroy, inverse_of: :task_board

  validates :name, presence: true, length: { maximum: 80 }

  scope :ordered, -> { order(:position, :id) }

  def self.default_column_names
    DEFAULT_COLUMNS.map { |c| I18n.t("tasks.default_columns.#{c[:name_key]}") }
  end

  # Cria o quadro com as colunas informadas (nomes); sem nomes, usa a sugestão.
  # Cores e a marca de "concluído" seguem a sugestão, por posição.
  def self.create_with_columns!(account:, name:, column_names: nil)
    names = Array(column_names).map { |n| n.to_s.strip }.reject(&:blank?).first(12)
    names = default_column_names if names.empty?
    transaction do
      board = account.task_boards.create!(name: name, position: account.task_boards.maximum(:position).to_i + 1)
      names.each_with_index do |column_name, index|
        suggestion = DEFAULT_COLUMNS[index] || {}
        board.columns.create!(name: column_name, position: index, color: suggestion[:color] || TaskColumn::COLORS[index % TaskColumn::COLORS.size],
                              done: index == names.size - 1 && names.size > 1)
      end
      board
    end
  end
end
