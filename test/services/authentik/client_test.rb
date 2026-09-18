# frozen_string_literal: true

require "test_helper"

class Authentik::ClientTest < ActiveSupport::TestCase
  test "管理者ユーザー名を管理者として認識する" do
    profile = { "preferred_username" => "myouou", "email" => "office@example.com" }

    assert Authentik::Client.send(:admin?, profile, "事務局")
  end
end
