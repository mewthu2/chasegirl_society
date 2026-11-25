# Tipo da chave PIX (CPF, CNPJ, e-mail, telefone, aleatória). Preenche só o que dá para saber
# com certeza pela chave já cadastrada; 11 dígitos soltos (CPF ou celular?) ficam para a equipe.
class AddPixKeyTypeToInfluencers < ActiveRecord::Migration[8.1]
  class Inf < ActiveRecord::Base
    self.table_name = "influencers"
  end

  def up
    add_column :influencers, :pix_key_type, :string
    Inf.where.not(pix_key: [nil, ""]).find_each do |i|
      key = i.pix_key.strip
      type =
        if key.include?("@") then "email"
        elsif key.match?(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/) then "random"
        elsif key.match?(/\A\d{3}\.\d{3}\.\d{3}-\d{2}\z/) then "cpf"
        elsif key.match?(/\A\d{2}\.?\d{3}\.?\d{3}\/?\d{4}-?\d{2}\z/) then "cnpj"
        elsif key.start_with?("+") || key.match?(/\A\(\d{2}\)/) then "phone"
        end
      i.update_columns(pix_key_type: type) if type
    end
  end

  def down
    remove_column :influencers, :pix_key_type
  end
end
