class AccountsController < ApplicationController
  # Criar conta / trocar de conta não exigem uma conta ativa prévia.
  skip_before_action :require_account, only: [:new, :create]
  skip_before_action :ensure_personal_account
  before_action :set_admin_account, only: [:edit, :update]

  def new
    @account = Account.new
  end

  # Configurações da conta (renomear). Só admin da conta.
  def edit
  end

  def update
    if @account.update(account_params)
      redirect_to edit_account_path(@account), notice: t("flash.accounts.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def create
    @account = Account.new(account_params)
    @account.owner = current_user

    if @account.save
      # Aprovação manual: só admin da plataforma ativa na hora; os demais entram
      # como `pending` e ficam sem acesso até serem aprovados no /admin.
      status = current_user.platform_admin? ? "active" : "pending"
      @account.memberships.create!(user: current_user, role: "owner", status: status)

      session[:locale] = @account.locale # UI já no idioma escolhido no cadastro
      if status == "active"
        session[:account_id] = @account.id
        redirect_to authenticated_root_path, notice: t("flash.accounts.created")
      else
        redirect_to pending_approval_path, notice: t("flash.accounts.created_pending")
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
      redirect_to authenticated_root_path, notice: t("flash.accounts.switched", account: account.name)
    else
      redirect_to authenticated_root_path, alert: t("flash.accounts.unavailable")
    end
  end

  private

  # Carrega a conta entre as do usuário e exige que ele seja admin dela.
  def set_admin_account
    @account = current_user.accounts.find(params[:id])
    return if current_user.admin_of?(@account)

    redirect_to authenticated_root_path, alert: t("flash.accounts.not_admin")
  end

  def account_params
    params.require(:account).permit(:name, :height_cm, :locale)
  end
end
