# frozen_string_literal: true

class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create authentik]
  rate_limit to: 10, within: 3.minutes, only: :create, with: lambda {
    redirect_to new_session_url, alert: "時間をおいてもう一度お試しください。"
  }

  def new
    return if flash[:alert].present? || !Authentik::Client.configured?

    begin_authentik_login
  end

  def create
    begin_authentik_login
  end

  def authentik
    if params[:error].present?
      redirect_to new_session_path, alert: "Authentikでのログインが取り消されました。"
      return
    end

    stored_state = session.delete(:authentik_state).to_s
    unless stored_state.present? && ActiveSupport::SecurityUtils.secure_compare(params[:state].to_s, stored_state)
      redirect_to new_session_path, alert: "ログイン情報の確認に失敗しました。もう一度ログインしてください。"
      return
    end

    user = Authentik::Client.authenticate(
      code: params[:code],
      redirect_uri: authentik_callback_url,
      nonce: session.delete(:authentik_nonce).to_s
    )
    start_new_session_for user
    redirect_to after_authentication_url
  rescue Authentik::AuthenticationError, Authentik::ConfigurationError, ActiveRecord::RecordInvalid => e
    redirect_to new_session_path, alert: e.message
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end

  private

  def begin_authentik_login
    state = SecureRandom.hex(24)
    nonce = SecureRandom.hex(24)
    session[:authentik_state] = state
    session[:authentik_nonce] = nonce

    redirect_to Authentik::Client.authorization_url(
      redirect_uri: authentik_callback_url,
      state: state,
      nonce: nonce
    ), allow_other_host: true
  rescue Authentik::ConfigurationError => e
    redirect_to new_session_path, alert: e.message
  end

  def authentik_callback_url
    ENV.fetch("AUTHENTIK_REDIRECT_URI") { "#{request.base_url}#{Authentik::Client.callback_path}" }
  end
end
