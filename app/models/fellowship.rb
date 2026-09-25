# frozen_string_literal: true

class Fellowship < ApplicationRecord
  MANAGED_FELLOWSHIPS = {
    "31101" => "埼玉",
    "31201" => "千葉",
    "31303" => "大江戸",
    "31304" => "羽田",
    "31305" => "お台場",
    "31407" => "かながわ",
    "31901" => "山梨",
    "32204" => "富士山",
    "32205" => "駿天"
  }.freeze

  has_many :users, dependent: :restrict_with_exception
  has_many :orders, dependent: :restrict_with_exception

  validates :code, format: { with: /\A\d{5}\z/, allow_blank: true }, uniqueness: { allow_blank: true }
  validates :name, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
  scope :available_to_users, -> { active.where(code: MANAGED_FELLOWSHIPS.keys) }

  def display_name
    [ code.presence, name ].compact.join(" ")
  end
end
