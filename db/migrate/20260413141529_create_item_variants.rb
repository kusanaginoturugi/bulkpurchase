class CreateItemVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :item_variants do |t|
      t.references :item, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :display_order, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :item_variants, [ :item_id, :name ], unique: true
  end
end
