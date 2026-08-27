# frozen_string_literal: true

require "json"
require "net/http"
require "securerandom"
require "uri"

AUTHENTIK_URL = ENV.fetch("AUTHENTIK_URL", "https://auth.showway.biz").delete_suffix("/")
API_TOKEN = ENV.fetch("AUTHENTIK_API_TOKEN")
APP_NAME = ENV.fetch("AUTHENTIK_APP_NAME", "bulkpurchase")
APP_SLUG = ENV.fetch("AUTHENTIK_APP_SLUG", "bulkpurchase")
LAUNCH_URL = ENV.fetch("AUTHENTIK_LAUNCH_URL", "https://bulkpurchase.showway.biz/")
CALLBACK_URL = ENV.fetch("AUTHENTIK_CALLBACK_URL", "https://bulkpurchase.showway.biz/session/authentik/callback")
CLIENT_ID = ENV.fetch("AUTHENTIK_CLIENT_ID", "bulkpurchase")
CLIENT_SECRET = ENV.fetch("AUTHENTIK_CLIENT_SECRET", SecureRandom.hex(32))

def request(method, path, body = nil)
  uri = URI("#{AUTHENTIK_URL}/api/v3#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"

  request = method.new(uri)
  request["Authorization"] = "Bearer #{API_TOKEN}"
  request["Content-Type"] = "application/json"
  request.body = JSON.dump(body) if body

  response = http.request(request)
  unless response.is_a?(Net::HTTPSuccess)
    warn response.body
    raise "#{path} の実行に失敗しました: #{response.code}"
  end

  response.body.to_s.empty? ? {} : JSON.parse(response.body)
end

def find_one(path, name)
  response = request(Net::HTTP::Get, "#{path}?search=#{URI.encode_www_form_component(name)}")
  Array(response["results"]).find { |record| record["name"] == name || record["slug"] == name }
end

auth_flow = find_one("/flows/instances/", "default-provider-authorization-implicit-consent") ||
            find_one("/flows/instances/", "default-provider-authorization-explicit-consent")
raise "認可フローが見つかりません。" unless auth_flow

invalidation_flow = find_one("/flows/instances/", "default-provider-invalidation-flow")
raise "ログアウト用フローが見つかりません。" unless invalidation_flow

provider = find_one("/providers/oauth2/", APP_NAME)
provider ||= request(
  Net::HTTP::Post,
  "/providers/oauth2/",
  {
    name: APP_NAME,
    authorization_flow: auth_flow["pk"],
    invalidation_flow: invalidation_flow["pk"],
    client_type: "confidential",
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    grant_types: [ "authorization_code" ],
    access_code_validity: "minutes=1",
    access_token_validity: "minutes=5",
    refresh_token_validity: "days=30",
    refresh_token_threshold: "days=1",
    include_claims_in_id_token: true,
    redirect_uris: [
      {
        matching_mode: "strict",
        url: CALLBACK_URL
      }
    ],
    sub_mode: "hashed_user_id",
    issuer_mode: "per_provider"
  }
)

application = find_one("/core/applications/", APP_SLUG)
application ||= request(
  Net::HTTP::Post,
  "/core/applications/",
  {
    name: APP_NAME,
    slug: APP_SLUG,
    provider: provider.fetch("pk"),
    meta_launch_url: LAUNCH_URL,
    policy_engine_mode: "any"
  }
)

puts JSON.pretty_generate(
  application: application.slice("name", "slug"),
  provider: provider.slice("pk", "name", "client_id"),
  rails_environment: {
    AUTHENTIK_ISSUER: "#{AUTHENTIK_URL}/application/o/#{APP_SLUG}/",
    AUTHENTIK_CLIENT_ID: CLIENT_ID,
    AUTHENTIK_CLIENT_SECRET: CLIENT_SECRET,
    AUTHENTIK_REDIRECT_URI: CALLBACK_URL
  }
)
