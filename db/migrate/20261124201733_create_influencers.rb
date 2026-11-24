class CreateInfluencers < ActiveRecord::Migration[8.1]
  def change
    create_table :influencers do |t|
      t.string :name, null: false
      t.string :instagram
      t.string :tiktok
      t.string :city
      t.integer :followers
      t.string :coupon_code
      t.integer :feed_goal, null: false, default: 1
      t.integer :stories_goal, null: false, default: 4
      t.integer :tiktok_goal, null: false, default: 0
      t.decimal :cash_value, precision: 10, scale: 2, null: false, default: 0
      t.decimal :permuta_value, precision: 10, scale: 2, null: false, default: 0
      t.boolean :cash_is_permuta, null: false, default: false
      t.date :starts_on
      t.date :ends_on
      t.string :pix_key
      t.string :phone
      t.text :notes
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :influencers, :coupon_code, unique: true, where: "coupon_code IS NOT NULL"
    add_index :influencers, :instagram

    add_column :users, :name, :string
    add_column :users, :role, :string, null: false, default: "influencer"
    add_reference :users, :influencer, foreign_key: true, index: { unique: true }
  end
end
