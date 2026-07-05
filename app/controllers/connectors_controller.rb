# Conectores: integrações que puxam dados sozinhas. Fluxo OAuth do GitHub
# (state na sessão contra CSRF) + sincronizar agora + desconectar.
class ConnectorsController < ApplicationController
  def github_connect
    return redirect_to setup_path, alert: t("connectors.not_configured") unless Connectors::Github.configured?

    state = SecureRandom.hex(16)
    session[:github_oauth_state] = state
    redirect_to Connectors::Github.authorize_url(state: state, redirect_uri: github_callback_connectors_url),
                allow_other_host: true
  end

  def github_callback
    unless params[:state].present? && params[:state] == session.delete(:github_oauth_state)
      return redirect_to setup_path, alert: t("connectors.state_mismatch")
    end

    token = Connectors::Github.exchange_code(params[:code], redirect_uri: github_callback_connectors_url)
    login = Connectors::Github.viewer_login(token)

    connector = current_account.connectors.find_or_initialize_by(kind: "github")
    first_time = connector.new_record? || connector.last_synced_at.nil?
    connector.access_token = token
    connector.status = "active"
    connector.last_error = nil
    connector.settings = connector.settings.merge("login" => login)
    connector.save!

    ConnectorSyncJob.perform_later(connector.id, full: first_time)
    redirect_to setup_path, notice: t("connectors.connected", login: login)
  rescue StandardError => e
    redirect_to setup_path, alert: t("connectors.connect_failed", error: e.message.to_s.first(120))
  end

  def sync
    connector = current_account.connectors.find(params[:id])
    ConnectorSyncJob.perform_later(connector.id)
    redirect_to setup_path, notice: t("connectors.syncing")
  end

  def destroy
    connector = current_account.connectors.find(params[:id])
    connector.destroy
    redirect_to setup_path, notice: t("connectors.removed")
  end
end
