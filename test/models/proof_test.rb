require "test_helper"

class ProofTest < ActiveSupport::TestCase
  setup do
    @inf = Influencer.create!(name: "Bia", feed_goal: 1, stories_goal: 4, tiktok_goal: 0, cash_value: 1000)
  end

  def photo = fixture_file_upload("story.png", "image/png")

  test "exige foto" do
    proof = @inf.proofs.new(kind: "feed", link: "https://instagram.com/p/x")
    assert_not proof.valid?
    assert proof.errors[:images].any?
  end

  test "exige link" do
    proof = @inf.proofs.new(kind: "feed", images: [photo])
    assert_not proof.valid?
    assert proof.errors[:link].any?
  end

  test "várias fotos contam como uma única tarefa" do
    proof = @inf.proofs.create!(kind: "stories", quantity: 5, link: "instagram.com/stories/bia", images: [photo, photo, photo])
    assert_equal "https://instagram.com/stories/bia", proof.link
    assert_equal 1, proof.quantity
    assert_equal 3, proof.images.count
    assert_equal 1, @inf.statement_for(Date.current).tap { proof.approve!(by: users(:admin)) }.delivered_for("stories")
  end

  test "não aceita canal não contratado" do
    assert_not @inf.proofs.new(kind: "tiktok", link: "https://tiktok.com/x", images: [photo]).valid?
  end
end
