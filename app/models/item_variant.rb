class ItemVariant < ApplicationRecord
  belongs_to :item
  has_many :order_items, dependent: :restrict_with_exception

  validates :name, presence: true

  scope :active, -> { where(active: true) }
end
