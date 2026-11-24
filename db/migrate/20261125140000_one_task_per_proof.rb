# Cada comprovação passa a valer uma tarefa (várias fotos por tarefa).
class OneTaskPerProof < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE proofs SET quantity = 1 WHERE quantity <> 1"
  end

  def down; end
end
