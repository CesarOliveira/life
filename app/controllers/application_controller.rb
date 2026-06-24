class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :require_account, unless: :devise_controller?

  include Pagy::Backend

  helper_method :current_account, :current_membership

  protected

  def current_user_or_nil
    current_user
  end

  # Devise: permite o campo customizado :name no cadastro e na edição.
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name])
  end

  # Conta (tenant) ativa na sessão. Resolve a partir da sessão e cai para a
  # primeira conta ativa do usuário.
  def current_account
    return @current_account if defined?(@current_account)

    @current_account =
      if session[:account_id]
        current_user&.active_accounts&.find_by(id: session[:account_id])
      end
    @current_account ||= current_user&.active_accounts&.first
    session[:account_id] = @current_account&.id
    @current_account
  end

  def current_membership
    return @current_membership if defined?(@current_membership)
    @current_membership = current_user&.membership_for(current_account)
  end

  # Usuário autenticado precisa de uma conta ativa para usar o app.
  def require_account
    return unless current_user
    return if current_account

    if current_user.memberships.pending.exists?
      redirect_to pending_approval_path
    else
      redirect_to onboarding_path
    end
  end
end
