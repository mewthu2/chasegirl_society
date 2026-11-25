# Stories passa a contar 1 entrega por print: recalcula as comprovações já enviadas.
class RecountStoriesProofsByPrint < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE proofs SET quantity = GREATEST(1, (
        SELECT COUNT(*) FROM active_storage_attachments a
        WHERE a.record_type = 'Proof' AND a.record_id = proofs.id AND a.name = 'images'
      ))
      WHERE kind = 'stories'
    SQL
  end

  def down
    execute "UPDATE proofs SET quantity = 1 WHERE kind = 'stories'"
  end
end
