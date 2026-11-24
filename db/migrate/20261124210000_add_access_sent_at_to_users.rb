class AddAccessSentAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :access_sent_at, :datetime
  end
end
