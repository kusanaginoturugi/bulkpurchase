# frozen_string_literal: true

require "test_helper"

class Authentik::ClientTest < ActiveSupport::TestCase
  test "管理者ユーザー名を管理者として認識する" do
    profile = { "preferred_username" => "myouou", "email" => "office@example.com" }

    assert Authentik::Client.send(:admin?, profile, "事務局")
  end

  test "Authentikのグループから指定された伝道会だけを取得する" do
    Fellowship.create!(code: "99300", name: "聖明王院", active: true, enabled: true)

    assert_equal fellowships(:one), Authentik::Client.send(:fellowship_from_groups, [ "埼玉" ])
    assert_nil Authentik::Client.send(:fellowship_from_groups, [ "聖明王院" ])
  end
end
