require "test_helper"

class MonthlyStatementTest < ActiveSupport::TestCase
  setup do
    @inf = Influencer.create!(name: "Ana", instagram: "ana", feed_goal: 1, stories_goal: 2, tiktok_goal: 0,
                              cash_value: 1000, coupon_code: "CGANA")
    @month = Date.new(2026, 11, 1)
    @admin = users(:admin)
  end

  def with_fake_coupon(fake)
    original = ShopifyCoupon.method(:new)
    ShopifyCoupon.define_singleton_method(:new) { |*| fake }
    yield
  ensure
    ShopifyCoupon.singleton_class.send(:remove_method, :new)
  end

  def proof(kind, qty = 1)
    @inf.proofs.create!(kind:, quantity: qty, posted_on: @month + 3, link: "https://instagram.com/p/x")
  end

  test "libera a parte de cada canal cumprido" do
    proof("feed").approve!(by: @admin)
    st = @inf.statement_for(@month)
    assert_equal 500.to_d, st.amount_due
    assert_not st.goal_met?
  end

  test "comprovação pendente não conta" do
    proof("feed")
    assert_equal 0, @inf.statement_for(@month).amount_due
  end

  test "ao bater a meta aumenta o cupom uma única vez" do
    calls = 0
    fake = Object.new
    fake.define_singleton_method(:increment_usage_limit!) { calls += 1; 7 }
    with_fake_coupon(fake) do
      proof("feed").approve!(by: @admin)
      proof("stories", 2).approve!(by: @admin)
      proof("stories").approve!(by: @admin)
    end
    st = @inf.statement_for(@month)
    assert st.goal_met?
    assert_equal 1000.to_d, st.amount_due
    assert_equal "done", st.coupon_status
    assert_equal 7, st.coupon_usage_limit
    assert_equal 1, calls
  end

  test "falha na Shopify fica registrada para tentar de novo" do
    fake = Object.new
    fake.define_singleton_method(:increment_usage_limit!) { raise ShopifyCoupon::Error, "sem permissão" }
    with_fake_coupon(fake) do
      proof("feed").approve!(by: @admin)
      proof("stories", 2).approve!(by: @admin)
    end
    st = @inf.statement_for(@month)
    assert_equal "error", st.coupon_status
    assert_equal "sem permissão", st.coupon_error
  end
end
