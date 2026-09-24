# frozen_string_literal: true

require "test_helper"

class TendoPdfUploaderTest < ActiveSupport::TestCase
  test "天道の送信フォームに必要なPDFと送信先を組み立てる" do
    order_cycle = OrderCycle.new(
      year: 2030,
      month: 4,
      cycle_number: 4,
      deadline_at: Time.zone.local(2030, 4, 1, 12),
      order_date: Date.new(2030, 4, 2),
      arrival_date: Date.new(2030, 4, 10),
      tendo_destination: "mirokuji"
    )
    body = TendoPdfUploader.new(order_cycle).send(:multipart_body, "test-boundary")

    assert_includes body, 'name="mirokuji"'
    assert_includes body, 'name="up_file[]"'
    assert_includes body, "Content-Type: application/pdf"
    assert_includes body, "%PDF"
  end
end
