# frozen_string_literal: true

require "test_helper"

class FellowshipTest < ActiveSupport::TestCase
  test "利用者向けの伝道会は指定された有効な伝道会だけ" do
    inactive = fellowships(:two)
    inactive.update!(active: false)
    Fellowship.create!(code: "99300", name: "聖明王院", active: true, enabled: true)

    assert_equal [ fellowships(:one) ], Fellowship.available_to_users.order(:code).to_a
  end
end
