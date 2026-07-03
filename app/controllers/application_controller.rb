class ApplicationController < ActionController::Base
  around_action :switch_locale
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :ensure_personal_account, if: :user_signed_in?, unless: :devise_controller?
  before_action :require_account, unless: :devise_controller?

  include Pagy::Backend

  helper_method :current_account, :current_membership

  protected

  # Define o idioma: ?locale= troca (persiste na sessão E na conta), senão usa
  # a sessão, senão o idioma da conta (definido no cadastro). Default: pt-BR.
  # NÃO usa o helper current_account aqui: o around_action roda antes de
  # ensure_personal_account e memoizaria nil para o request inteiro.
  def switch_locale(&action)
    available = I18n.available_locales.map(&:to_s)
    requested = params[:locale].to_s
    if available.include?(requested)
      session[:locale] = requested
      current_user&.accounts&.update_all(locale: requested) if user_signed_in?
    end
    account_locale = user_signed_in? ? current_user&.accounts&.pick(:locale) : nil
    locale =
      if available.include?(session[:locale].to_s)
        session[:locale]
      elsif available.include?(account_locale.to_s)
        account_locale
      else
        I18n.default_locale
      end
    I18n.with_locale(locale, &action)
  end

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

  # Modelo single-user: cada usuário tem 1 conta pessoal, criada sob demanda no
  # 1º acesso autenticado. Assim ninguém passa por onboarding/aprovação.
  def ensure_personal_account
    return if current_user.accounts.exists?

    locale = Account::LOCALES.include?(session[:locale].to_s) ? session[:locale] : "pt-BR"
    account = current_user.owned_accounts.create!(name: current_user.name.presence || I18n.t("accounts.personal_name"), locale: locale)
    current_user.memberships.create!(account: account, role: "owner", status: "active")
    session[:account_id] = account.id
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
