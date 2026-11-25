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

  test "tiktok: link e print" do
    @inf.update!(tiktok_goal: 1)
    assert_not @inf.proofs.new(kind: "tiktok", link: "https://tiktok.com/x").valid?
    assert_not @inf.proofs.new(kind: "tiktok", images: [photo]).valid?
    assert @inf.proofs.new(kind: "tiktok", link: "https://tiktok.com/x", images: [photo]).valid?
  end

  test "envio por mês: aceita o anterior, recusa futuro e mês já aprovado" do
    current = Date.current.beginning_of_month
    proof = @inf.proofs.create!(kind: "feed", link: "https://instagram.com/p/x", month: current.prev_month)
    assert_equal current.prev_month, proof.month
    assert_not @inf.proofs.new(kind: "feed", link: "https://instagram.com/p/x", month: current.next_month).valid?

    @inf.statement_for(current.prev_month).update_columns(review_status: "approved")
    assert_not @inf.proofs.new(kind: "feed", link: "https://instagram.com/p/x", month: current.prev_month).valid?
    assert_equal [current], Proof.month_options(@inf)
  end

  test "várias fotos contam como uma única tarefa" do
    @inf.update!(tiktok_goal: 1)
    proof = @inf.proofs.create!(kind: "tiktok", quantity: 5, link: "tiktok.com/@bia/1", images: [photo, photo, photo])
    assert_equal "https://tiktok.com/@bia/1", proof.link
    assert_equal 1, proof.quantity
    assert_equal 3, proof.images.count
    assert_equal 1, @inf.statement_for(Date.current).tap { proof.approve!(by: users(:admin)) }.delivered_for("tiktok")
  end

  test "não aceita canal não contratado" do
    assert_not @inf.proofs.new(kind: "tiktok", link: "https://tiktok.com/x", images: [photo]).valid?
  end
end
