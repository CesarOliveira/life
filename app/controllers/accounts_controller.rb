class AccountsController < ApplicationController
  # Criar conta / trocar de conta não exigem uma conta ativa prévia.
  skip_before_action :require_account, only: [:new, :create]

  def new
    @account = Account.new
  end

  def create
    @account = Account.new(account_params)
    @account.owner = current_user

    if @account.save
      # Aprovação manual: só admin da plataforma ativa na hora; os demais entram
      # como `pending` e ficam sem acesso até serem aprovados no /admin.
      status = current_user.platform_admin? ? "active" : "pending"
      @account.memberships.create!(user: current_user, role: "owner", status: status)

      if status == "active"
        session[:account_id] = @account.id
        redirect_to authenticated_root_path, notice: "Conta criada com sucesso."
      else
        redirect_to pending_approval_path,
          notice: "Conta criada. Aguarde a aprovação do administrador para começar a usar."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Troca a conta ativa na sessão (apenas entre as contas ativas do usuário).
  def switch
    account = current_user.active_accounts.find_by(id: params[:id])
    if account
      session[:account_id] = account.id
      redirect_to authenticated_root_path, notice: "Conta ativa: #{account.name}."
    else
      redirect_to authenticated_root_path, alert: "Conta indisponível."
    end
  end

  private

  def account_params
    params.require(:account).permit(:name)
  end
end
