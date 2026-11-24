class CreateMonthlyStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :monthly_statements do |t|
      t.references :influencer, null: false, foreign_key: true
      t.date :month, null: false
      t.decimal :amount_paid, precision: 10, scale: 2
      t.string :payment_status, null: false, default: "open"
      t.datetime :paid_at
      t.references :paid_by, foreign_key: { to_table: :users }
      t.text :payment_note
      t.string :coupon_status, null: false, default: "none"
      t.integer :coupon_usage_limit
      t.datetime :coupon_incremented_at
      t.text :coupon_error
      t.timestamps
    end
    add_index :monthly_statements, [:influencer_id, :month], unique: true
  end
end
