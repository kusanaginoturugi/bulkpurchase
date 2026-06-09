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
      rows.each { |row| upsert(row) }
    end

    Result.new(count: rows.size, master_updated_at: body["updated_at"])
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

  # enabled は同期で触らない (運用側のフラグ)。
  # name は bulkpurchase の表示で短名を使いたいので short_name を優先する。
  def upsert(row)
    fellowship = Fellowship.find_or_initialize_by(id: row.fetch("id"))
    fellowship.code = row["code"]
    fellowship.name = row["short_name"].presence || row["name"]
    fellowship.active = row["active"].to_i == 1
    fellowship.save!
  end
end
