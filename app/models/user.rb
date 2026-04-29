# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password
  belongs_to :organization
  has_many :sessions, dependent: :destroy
  has_many :orders, dependent: :restrict_with_exception

  enum :role, { user: "user", admin: "admin" }, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def role_label
    I18n.t("enums.user.role.#{role}", default: role)
  end

  def self.role_options
    roles.keys.map { |value| [ I18n.t("enums.user.role.#{value}", default: value), value ] }
  end

  validates :name, :email_address, :role, presence: true
  validates :email_address, uniqueness: { case_sensitive: false }

  scope :active, -> { where(active: true) }
end
