# Autorização de um cliente OAuth para ler os dados de uma conta. Os segredos
# (código, access token, refresh token) nunca são gravados: só o SHA-256 deles.
# == Schema Information
#
# Table name: oauth_grants
#
#  id                   :bigint           not null, primary key
#  access_expires_at    :datetime
#  access_token_digest  :string
#  code_challenge       :string
#  code_digest          :string
#  code_expires_at      :datetime
#  last_used_at         :datetime
#  redirect_uri         :string           not null
#  refresh_expires_at   :datetime
#  refresh_token_digest :string
#  resource             :string
#  revoked_at           :datetime
#  scope                :string           default("life:read"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  oauth_client_id      :bigint           not null
#  user_id              :bigint           not null
#
# Indexes
#
#  index_oauth_grants_on_access_token_digest   (access_token_digest) UNIQUE
#  index_oauth_grants_on_account_id            (account_id)
#  index_oauth_grants_on_code_digest           (code_digest) UNIQUE
#  index_oauth_grants_on_oauth_client_id       (oauth_client_id)
#  index_oauth_grants_on_refresh_token_digest  (refresh_token_digest) UNIQUE
#  index_oauth_grants_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (oauth_client_id => oauth_clients.id)
#  fk_rails_...  (user_id => users.id)
#
class OauthGrant < ApplicationRecord
  SCOPE = "life:read".freeze        # sempre concedido
  WRITE_SCOPE = "life:write".freeze  # opcional: criar/alterar tarefas, hábitos e peso
  SCOPES = [SCOPE, WRITE_SCOPE].freeze
  CODE_TTL = 10.minutes
  ACCESS_TTL = 1.hour
  REFRESH_TTL = 90.days

  belongs_to :account
  belongs_to :user
  belongs_to :oauth_client

  scope :active, -> { where(revoked_at: nil).where.not(refresh_token_digest: nil).where(refresh_expires_at: Time.current..) }

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def write?
    scope.to_s.split.include?(WRITE_SCOPE)
  end

  def allow_write!(allowed)
    update!(scope: allowed ? SCOPES.join(" ") : SCOPE)
  end

  # Autorização dona de um access token válido (ou nil). Atualiza o "último uso"
  # no máximo uma vez por minuto.
  def self.for_access_token(token)
    return nil if token.blank?

    grant = find_by(access_token_digest: digest(token), revoked_at: nil)
    return nil if grant.nil? || grant.access_expires_at.nil? || grant.access_expires_at < Time.current

    grant.update_column(:last_used_at, Time.current) if grant.last_used_at.nil? || grant.last_used_at < 1.minute.ago
    grant
  end

  # Emite o código de autorização (uso único, 10 min) e devolve o valor em claro.
  def issue_code!
    code = SecureRandom.urlsafe_base64(32)
    update!(code_digest: self.class.digest(code), code_expires_at: CODE_TTL.from_now)
    code
  end

  # Troca (código ou refresh) por um par novo de tokens; os anteriores morrem.
  def issue_tokens!
    access = SecureRandom.urlsafe_base64(32)
    refresh = SecureRandom.urlsafe_base64(48)
    update!(code_digest: nil, code_expires_at: nil,
            access_token_digest: self.class.digest(access), access_expires_at: ACCESS_TTL.from_now,
            refresh_token_digest: self.class.digest(refresh), refresh_expires_at: REFRESH_TTL.from_now)
    { access_token: access, token_type: "Bearer", expires_in: ACCESS_TTL.to_i, refresh_token: refresh, scope: scope }
  end

  def revoke!
    update!(revoked_at: Time.current, code_digest: nil, access_token_digest: nil, refresh_token_digest: nil)
  end

  # PKCE (S256): o verificador enviado na troca tem que gerar o desafio guardado.
  def pkce_valid?(verifier)
    return false if verifier.blank? || code_challenge.blank?

    expected = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier.to_s), padding: false)
    ActiveSupport::SecurityUtils.secure_compare(expected, code_challenge)
  end
end
