# Log de uma requisição recebida numa rota de ingestão. Somente diagnóstico —
# nada de negócio depende disso. Retenção limpa via job/manual.
# == Schema Information
#
# Table name: ingestion_logs
#
#  id             :bigint           not null, primary key
#  byte_size      :integer          default(0), not null
#  client_version :string
#  endpoint       :string           not null
#  ip             :string
#  query          :jsonb            not null
#  raw_body       :text
#  result         :jsonb            not null
#  status         :integer
#  created_at     :datetime         not null
#  account_id     :bigint
#
# Indexes
#
#  index_ingestion_logs_on_account_id               (account_id)
#  index_ingestion_logs_on_created_at               (created_at)
#  index_ingestion_logs_on_endpoint_and_created_at  (endpoint,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class IngestionLog < ApplicationRecord
  RAW_LIMIT = 10_000 # chars do corpo guardados

  belongs_to :account, optional: true

  scope :recent_first, -> { order(created_at: :desc) }

  def ok?
    status.to_i.between?(200, 299)
  end
end
