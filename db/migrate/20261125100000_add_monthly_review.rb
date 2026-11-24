class AddMonthlyReview < ActiveRecord::Migration[8.1]
  def change
    change_table :monthly_statements do |t|
      t.string :review_status, null: false, default: "open"
      t.datetime :reviewed_at
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.text :review_note
      t.decimal :amount_payable, precision: 10, scale: 2
      t.date :due_on
    end
    add_index :monthly_statements, :review_status
  end
end
