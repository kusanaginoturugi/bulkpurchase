# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

class MasterSync
  class FetchError < StandardError; end

  Result = Struct.new(:count, :master_updated_at, keyword_init: true)

  def self.run
    new.run
  end

  def initialize(base_url: Rails.application.config.masters_url)
    @base_url = base_url.to_s.sub(%r{/+\z}, "")
  end

  def run
    body = fetch_fellowships
    rows = body.fetch("data")

    ActiveRecord::Base.transaction do
      rows.filter { |row| Fellowship::MANAGED_FELLOWSHIPS.key?(row["code"].to_s) }.each { |row| upsert(row) }
      Fellowship.where.not(code: Fellowship::MANAGED_FELLOWSHIPS.keys).update_all(active: false, enabled: false)
    end

    Result.new(count: Fellowship::MANAGED_FELLOWSHIPS.size, master_updated_at: body["updated_at"])
  end

  private

  def fetch_fellowships
    uri = URI.parse("#{@base_url}/api/fellowships")
    response = Net::HTTP.get_response(uri)
    unless response.is_a?(Net::HTTPSuccess)
      raise FetchError, "masters /api/fellowships returned #{response.code}"
    end

    JSON.parse(response.body)
  end

  # 注文システムで利用する9伝道会だけを同期する。
  def upsert(row)
    code = row.fetch("code").to_s
    fellowship = Fellowship.find_or_initialize_by(code: code)
    fellowship.name = Fellowship::MANAGED_FELLOWSHIPS.fetch(code)
    fellowship.active = true
    fellowship.enabled = true
    fellowship.save!
  end
end
