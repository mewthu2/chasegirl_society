class CreateProofs < ActiveRecord::Migration[8.1]
  def change
    create_table :proofs do |t|
      t.references :influencer, null: false, foreign_key: true
      t.references :submitted_by, foreign_key: { to_table: :users }
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.date :month, null: false
      t.string :kind, null: false
      t.integer :quantity, null: false, default: 1
      t.date :posted_on
      t.string :link
      t.text :description
      t.string :status, null: false, default: "pending"
      t.text :review_note
      t.datetime :reviewed_at
      t.timestamps
    end
    add_index :proofs, [:influencer_id, :month, :kind]
    add_index :proofs, :status
  end
end
