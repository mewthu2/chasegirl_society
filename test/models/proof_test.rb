require "test_helper"

class ProofTest < ActiveSupport::TestCase
  setup do
    @inf = Influencer.create!(name: "Bia", feed_goal: 1, stories_goal: 4, tiktok_goal: 0, cash_value: 1000)
  end

  def photo = fixture_file_upload("story.png", "image/png")

  test "feed: só link" do
    assert @inf.proofs.new(kind: "feed", link: "https://instagram.com/p/x").valid?
    proof = @inf.proofs.new(kind: "feed", images: [photo])
    assert_not proof.valid?
    assert proof.errors[:link].any?
  end

  test "stories: só print, sem link" do
    proof = @inf.proofs.new(kind: "stories", link: "https://instagram.com/stories/x")
    assert_not proof.valid?
    assert proof.errors[:images].any?
    proof = @inf.proofs.create!(kind: "stories", link: "https://instagram.com/stories/x", images: [photo])
    assert_nil proof.link
  end

  test "tiktok: só link" do
    @inf.update!(tiktok_goal: 1)
    assert @inf.proofs.new(kind: "tiktok", link: "https://tiktok.com/x").valid?
    assert_not @inf.proofs.new(kind: "tiktok", images: [photo]).valid?
  end

  test "envio só do mês atual; cumprido o mês, só no mês seguinte" do
    current = Date.current.beginning_of_month
    proof = @inf.proofs.create!(kind: "feed", link: "https://instagram.com/p/x", month: current)
    assert_equal current, proof.month
    assert_not @inf.proofs.new(kind: "feed", link: "https://instagram.com/p/x", month: current.prev_month).valid?
    assert_not @inf.proofs.new(kind: "feed", link: "https://instagram.com/p/x", month: current.next_month).valid?
    assert_equal [current], Proof.month_options(@inf)

    @inf.statement_for(current).update_columns(review_status: "approved")
    assert_not @inf.proofs.new(kind: "feed", link: "https://instagram.com/p/x", month: current).valid?
    assert_empty Proof.month_options(@inf)
  end

  test "stories: cada print conta como uma entrega" do
    proof = @inf.proofs.create!(kind: "stories", quantity: 5, images: [photo, photo, photo])
    assert_equal 3, proof.quantity
    assert_equal 3, @inf.statement_for(Date.current).tap { proof.approve!(by: users(:admin)) }.delivered_for("stories")
  end

  test "stories: prints adicionados depois também contam" do
    proof = @inf.proofs.create!(kind: "stories", images: [photo])
    proof.images.attach(photo)
    proof.update!(description: "mais um")
    assert_equal 2, proof.reload.quantity
  end

  test "feed: continua uma entrega por envio" do
    assert_equal 1, @inf.proofs.create!(kind: "feed", link: "https://instagram.com/p/x", quantity: 4).quantity
  end

  test "não aceita canal não contratado" do
    assert_not @inf.proofs.new(kind: "tiktok", link: "https://tiktok.com/x", images: [photo]).valid?
  end
end
