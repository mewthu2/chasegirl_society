require "test_helper"

class InfluencerTest < ActiveSupport::TestCase
  def build(**attrs)
    Influencer.new({ name: "Teste", feed_goal: 1, stories_goal: 4, tiktok_goal: 1, cash_value: 1000 }.merge(attrs))
  end

  test "com TikTok divide o cachê em 3 partes que somam o total" do
    inf = build
    assert_equal %w[feed stories tiktok], inf.channels
    assert_equal 33.33, inf.share_percent("feed")
    assert_equal [333.33, 333.33, 333.34].map(&:to_d), inf.channel_values.values
    assert_equal 1000.to_d, inf.channel_values.values.sum
  end

  test "sem TikTok divide 50% para cada" do
    inf = build(tiktok_goal: 0)
    assert_equal 50.0, inf.share_percent("stories")
    assert_equal({ "feed" => 500.to_d, "stories" => 500.to_d }, inf.channel_values)
  end

  test "só permuta não gera cachê em dinheiro" do
    assert_equal 0, build(cash_is_permuta: true).channel_values.values.sum
  end

  test "exige ao menos um canal" do
    assert_not build(feed_goal: 0, stories_goal: 0, tiktok_goal: 0).valid?
  end

  test "chave PIX exige o tipo e mostra junto" do
    inf = Influencer.create!(name: "Pix", feed_goal: 1, stories_goal: 0, tiktok_goal: 0, cash_value: 1000)
    assert_not inf.update(pix_key: "123.456.789-00")
    assert_includes inf.errors[:pix_key_type], "informe o tipo da chave PIX"
    assert inf.update(pix_key: "123.456.789-00", pix_key_type: "cpf")
    assert_equal "CPF · 123.456.789-00", inf.pix_label
    assert_not inf.update(pix_key_type: "outro")
  end

  test "adivinha o tipo da chave só quando não há dúvida" do
    assert_equal "email", Influencer.guess_pix_key_type("ana@gmail.com")
    assert_equal "cnpj", Influencer.guess_pix_key_type("12.345.678/0001-90")
    assert_equal "random", Influencer.guess_pix_key_type("123e4567-e89b-12d3-a456-426614174000")
    assert_nil Influencer.guess_pix_key_type("11999990000")
  end
end
