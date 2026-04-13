class User < ApplicationRecord
  has_secure_password
  belongs_to :organization
  has_many :sessions, dependent: :destroy
  has_many :orders, dependent: :restrict_with_exception

  enum :role, { user: "user", admin: "admin" }, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, :email_address, :role, presence: true

  scope :active, -> { where(active: true) }
end
