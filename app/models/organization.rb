# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :users, dependent: :restrict_with_exception
  has_many :orders, dependent: :restrict_with_exception

  validates :code, format: { with: /\A\d{5}\z/, allow_blank: true }, uniqueness: { allow_blank: true }
  validates :name, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }

  def display_name
    [code.presence, name].compact.join(" ")
  end
end
