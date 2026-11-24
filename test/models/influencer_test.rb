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
end
