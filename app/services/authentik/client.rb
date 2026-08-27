# frozen_string_literal: true

require "base64"
require "json"
require "net/http"
require "securerandom"
require "uri"

module Authentik
  class ConfigurationError < StandardError; end
  class AuthenticationError < StandardError; end

  class Client
    DEFAULT_ISSUER = "https://auth.showway.biz/application/o/bulkpurchase/"
    REQUIRED_GROUP = "myouou"
    DEFAULT_ADMIN_NAMES = [ "尾ノ上裕美" ].freeze

    class << self
      def configured?
        client_id.present? && client_secret.present?
      end

      def authorization_url(redirect_uri:, state:, nonce:)
        ensure_configured!

        uri = URI(discovery.fetch("authorization_endpoint"))
        uri.query = URI.encode_www_form(
          client_id: client_id,
          redirect_uri: redirect_uri,
          response_type: "code",
          scope: "openid email profile groups",
          state: state,
          nonce: nonce
        )
        uri.to_s
      end

      def authenticate(code:, redirect_uri:, nonce:)
        ensure_configured!

        tokens = request_token(code:, redirect_uri:)
        profile = request_userinfo(tokens.fetch("access_token"))
        id_token_profile = decoded_id_token(tokens["id_token"])
        if id_token_profile.present?
          raise AuthenticationError, "ログイン情報の確認に失敗しました。もう一度ログインしてください。" if id_token_profile["nonce"].present? && id_token_profile["nonce"] != nonce

          profile = id_token_profile.merge(profile)
        end

        user_from_profile(profile)
      rescue KeyError, JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
        raise AuthenticationError, "Authentikとの通信に失敗しました。時間をおいてもう一度お試しください。"
      end

      def issuer
        ENV.fetch("AUTHENTIK_ISSUER", DEFAULT_ISSUER).to_s.then { |value| value.end_with?("/") ? value : "#{value}/" }
      end

      def callback_path
        "/session/authentik/callback"
      end

      def required_group
        ENV.fetch("AUTHENTIK_REQUIRED_GROUP", REQUIRED_GROUP)
      end

      private

      def client_id
        ENV["AUTHENTIK_CLIENT_ID"].presence || Rails.application.credentials.dig(:authentik, :client_id)
      end

      def client_secret
        ENV["AUTHENTIK_CLIENT_SECRET"].presence || Rails.application.credentials.dig(:authentik, :client_secret)
      end

      def ensure_configured!
        return if configured?

        raise ConfigurationError, "Authentikの接続設定が未設定です。"
      end

      def discovery
        @discovery ||= begin
          url = URI.join(issuer, ".well-known/openid-configuration")
          response = Net::HTTP.get_response(url)
          if response.is_a?(Net::HTTPSuccess) && response["content-type"].to_s.include?("json")
            JSON.parse(response.body)
          else
            fallback_discovery
          end
        rescue JSON::ParserError
          fallback_discovery
        end
      end

      def fallback_discovery
        root = URI(issuer)
        base = "#{root.scheme}://#{root.host}"
        {
          "authorization_endpoint" => "#{base}/application/o/authorize/",
          "token_endpoint" => "#{base}/application/o/token/",
          "userinfo_endpoint" => "#{base}/application/o/userinfo/"
        }
      end

      def request_token(code:, redirect_uri:)
        response = post_form(
          discovery.fetch("token_endpoint"),
          grant_type: "authorization_code",
          code: code,
          redirect_uri: redirect_uri,
          client_id: client_id,
          client_secret: client_secret
        )
        JSON.parse(response.body)
      end

      def request_userinfo(access_token)
        uri = URI(discovery.fetch("userinfo_endpoint"))
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{access_token}"

        response = http(uri).request(request)
        raise AuthenticationError, "Authentikのユーザー情報を取得できませんでした。" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      end

      def post_form(url, params)
        uri = URI(url)
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(params)

        response = http(uri).request(request)
        raise AuthenticationError, "Authentikの認証に失敗しました。" unless response.is_a?(Net::HTTPSuccess)

        response
      end

      def http(uri)
        Net::HTTP.new(uri.host, uri.port).tap do |client|
          client.use_ssl = uri.scheme == "https"
          client.open_timeout = 5
          client.read_timeout = 10
        end
      end

      def decoded_id_token(id_token)
        _header, payload, = id_token.split(".")
        return {} if payload.blank?

        JSON.parse(Base64.urlsafe_decode64(payload.ljust((payload.length + 3) & ~3, "=")))
      rescue JSON::ParserError, ArgumentError
        {}
      end

      def user_from_profile(profile)
        groups = Array(profile["groups"] || profile["ak_groups"]).map(&:to_s)
        raise AuthenticationError, "ログインできるグループに所属していません。" unless groups.include?(required_group)

        fellowship = fellowship_from_groups(groups)
        raise AuthenticationError, "伝道会グループが見つかりません。" unless fellowship

        email = profile["email"].presence || profile["preferred_username"].presence
        raise AuthenticationError, "メールアドレスを取得できませんでした。" if email.blank?

        name = profile["name"].presence || profile["preferred_username"].presence || email
        user = User.find_by(authentik_subject: profile["sub"]) if profile["sub"].present?
        user ||= User.find_or_initialize_by(email_address: email)

        user.tap do |user|
          user.email_address = email
          user.name = name
          user.fellowship = fellowship
          user.role = admin?(profile, name) ? :admin : :user
          user.active = true
          user.authentik_subject = profile["sub"] if user.has_attribute?(:authentik_subject)
          user.authentik_groups = groups.join("\n") if user.has_attribute?(:authentik_groups)
          user.password = SecureRandom.base58(32) if user.new_record?
          user.save!
        end
      end

      def fellowship_from_groups(groups)
        normalized_groups = groups.index_by { |group| normalize(group) }
        Fellowship.active.find_each.find do |fellowship|
          normalized_groups.key?(normalize(fellowship.name)) ||
            normalized_groups.key?(normalize(fellowship.display_name)) ||
            normalized_groups.key?(normalize(fellowship.code))
        end
      end

      def admin?(profile, name)
        admin_names.include?(name.to_s) || admin_emails.include?(profile["email"].to_s.downcase)
      end

      def admin_names
        ENV.fetch("AUTHENTIK_ADMIN_NAMES", DEFAULT_ADMIN_NAMES.join(",")).split(",").map(&:strip)
      end

      def admin_emails
        ENV.fetch("AUTHENTIK_ADMIN_EMAILS", "").split(",").map { |email| email.strip.downcase }.reject(&:blank?)
      end

      def normalize(value)
        value.to_s.tr("　", " ").squish.downcase
      end
    end
  end
end
