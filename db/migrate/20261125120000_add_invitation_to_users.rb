class AddInvitationToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :invited_at, :datetime
    add_column :users, :activated_at, :datetime
    # Quem já existe já tem senha definida.
    execute "UPDATE users SET activated_at = created_at"
  end

  def down
    remove_column :users, :invited_at
    remove_column :users, :activated_at
  end
end
