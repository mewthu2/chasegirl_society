# O @ do Instagram passa a ser login da influenciadora: precisa ser único (sem diferenciar maiúsculas).
class UniqueInstagram < ActiveRecord::Migration[8.1]
  def change
    remove_index :influencers, :instagram
    add_index :influencers, "LOWER(instagram)", unique: true, where: "instagram IS NOT NULL", name: "index_influencers_on_lower_instagram"
  end
end
