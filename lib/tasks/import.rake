require "csv"

namespace :import do
  # Importa influenciadoras de um CSV exportado da aba "chasegirl_society" (colunas A–P).
  #   bin/rails "import:influencers[caminho.csv]"
  # Atualiza quem já existe (procura por @instagram). Não cria acessos.
  desc "Importa influenciadoras de um CSV (aba chasegirl_society)"
  task :influencers, [:path] => :environment do |_, args|
    path = args[:path] or abort("Informe o caminho do CSV")
    to_i = ->(v) { v.to_s.gsub(/[^\d]/, "").presence&.to_i }
    to_d = ->(v) { v.to_s.strip.match?(/\A\d+([.,]\d+)?\z/) ? v.to_s.tr(",", ".").to_d : nil }
    to_date = ->(v) { Date.parse(v.to_s) rescue nil }
    clean_key = ->(v) { s = v.to_s.delete("\u202A\u202C").tr("\u2011\u00A0", "- ").strip; s.match?(/\A\d+\.0\z/) ? s.sub(/\.0\z/, "") : s.presence }

    created = updated = 0
    CSV.foreach(path, headers: true) do |row|
      name = row["Nome"].to_s.strip
      next if name.blank?

      instagram = row["@Instagram"].to_s.strip.delete_prefix("@").presence
      inf = (instagram && Influencer.find_by(instagram:)) || Influencer.find_or_initialize_by(name:)
      cash = row["VALOR DO PIX"].to_s
      tiktok = row["@Tiktok"].to_s.strip.presence
      tiktok_goal = to_i.(row["COMBINADO TIKTOK/POST"]) || 0
      tiktok_goal = 0 if tiktok.nil?

      inf.assign_attributes(
        name:, instagram:, tiktok:, city: row["Cidade/Estado"].to_s.strip.presence,
        followers: to_i.(row["Seguidores"]), coupon_code: row["CUPOM"].to_s.strip.presence,
        feed_goal: to_i.(row["COMBINADO INSTA/FEED"]) || 0, stories_goal: to_i.(row["COMBINADO INSTA/STORIES"]) || 0,
        tiktok_goal:, cash_value: to_d.(cash) || 0, cash_is_permuta: cash.strip.casecmp?("PERMUTA"),
        permuta_value: to_d.(row["PERMUTA"]) || 0, starts_on: to_date.(row["INCIO"]), ends_on: to_date.(row["FIM"]),
        pix_key: (k = clean_key.(row["CHAVE/PIX"])) && !k.casecmp?("PERMUTA") ? k : inf.pix_key,
        phone: clean_key.(row["TELEFONE"])
      )
      was_new = inf.new_record?
      if inf.save
        was_new ? created += 1 : updated += 1
      else
        puts "  ! #{name}: #{inf.errors.full_messages.to_sentence}"
      end
    end
    puts "Importação concluída: #{created} novas, #{updated} atualizadas."
  end
end
