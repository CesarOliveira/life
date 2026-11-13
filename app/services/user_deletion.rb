# Exclusão definitiva de um usuário, a pedido dele (exigência da App Store e da LGPD).
#
# - Contas em que ele é o único membro ativo são apagadas com tudo dentro: tempo de
#   tela, saúde, treinos, tarefas, hábitos, exames, peso, tokens e autorizações.
# - Contas compartilhadas com outros membros ativos continuam existindo: ele sai,
#   a posse passa para outro membro e as referências a ele viram "sem autor".
# - Administradores da plataforma não se excluem por aqui (evita apagar por
#   engano quem administra o serviço).
class UserDeletion
  Result = Struct.new(:ok, :error, :deleted_accounts, :left_accounts, keyword_init: true) do
    def ok? = ok
  end

  def initialize(user)
    @user = user
  end

  def blocked_reason
    return :platform_admin if @user.platform_admin? || @user.super_admin?

    nil
  end

  def call
    reason = blocked_reason
    return Result.new(ok: false, error: reason) if reason

    deleted = 0
    left = 0
    ActiveRecord::Base.transaction do
      @user.accounts.distinct.to_a.each do |account|
        others = account.memberships.active.where.not(user_id: @user.id).order(:created_at).to_a
        if others.empty?
          account.destroy!
          deleted += 1
        else
          leave(account, others)
          left += 1
        end
      end
      # Contas que ele possui sem ser membro (dado legado): só solta a posse.
      Account.where(owner_id: @user.id).update_all(owner_id: nil)
      detach_authorship
      @user.roles.clear
      @user.reload.destroy!
    end
    Result.new(ok: true, deleted_accounts: deleted, left_accounts: left)
  end

  private

  # Sai de uma conta compartilhada; se era o dono, passa a posse adiante.
  def leave(account, others)
    if account.owner_id == @user.id
      heir = others.find(&:admin?) || others.first
      heir.update!(role: "owner")
      account.update!(owner_id: heir.user_id)
    end
    account.memberships.where(user_id: @user.id).destroy_all
    account.oauth_grants.where(user_id: @user.id).destroy_all
  end

  # O que ele criou em contas que continuam existindo fica sem autor.
  def detach_authorship
    Task.where(creator_id: @user.id).update_all(creator_id: nil)
    TaskComment.where(user_id: @user.id).update_all(user_id: nil)
    TaskEvent.where(user_id: @user.id).update_all(user_id: nil)
  end
end
