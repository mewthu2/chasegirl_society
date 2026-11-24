require "test_helper"

class MonthlyStatementTest < ActiveSupport::TestCase
  setup do
    @inf = Influencer.create!(name: "Ana", instagram: "ana", feed_goal: 1, stories_goal: 2, tiktok_goal: 0,
                              cash_value: 1000, coupon_code: "CGANA")
    @month = Date.new(2026, 10, 1)
    @admin = users(:admin)
  end

  def with_fake_coupon(fake)
    ShopifyCoupon.define_singleton_method(:new) { |*| fake }
    yield
  ensure
    ShopifyCoupon.singleton_class.send(:remove_method, :new)
  end

  def fake_coupon(limit: 7, error: nil)
    calls = []
    fake = Object.new
    fake.define_singleton_method(:increment_usage_limit!) { calls << 1; error ? raise(ShopifyCoupon::Error, error) : limit }
    [fake, calls]
  end

  def proof(kind, qty = 1)
    @inf.proofs.create!(kind:, quantity: qty, posted_on: @month + 3, link: "https://instagram.com/p/x",
                        images: [fixture_file_upload("story.png", "image/png")])
  end

  test "calendário: conferência de 1 a 10 do mês seguinte, pagamento dia 10" do
    assert_equal Date.new(2026, 11, 1), MonthlyStatement.review_start(@month)
    assert_equal Date.new(2026, 11, 10), MonthlyStatement.due_date(@month)
    assert_equal :running, MonthlyStatement.phase(@month, Date.new(2026, 10, 31))
    assert_equal :review, MonthlyStatement.phase(@month, Date.new(2026, 11, 10))
    assert_equal :closed, MonthlyStatement.phase(@month, Date.new(2026, 11, 11))
    assert_equal Date.new(2026, 10, 1), MonthlyStatement.review_month(Date.new(2026, 11, 5))
  end

  test "sugestão de valor libera a parte de cada canal cumprido" do
    proof("feed").approve!(by: @admin)
    assert_equal 500.to_d, @inf.statement_for(@month).amount_due
  end

  test "aprovar comprovação não mexe no cupom nem cria a pagar" do
    fake, calls = fake_coupon
    with_fake_coupon(fake) do
      proof("feed").approve!(by: @admin)
      proof("stories", 2).approve!(by: @admin)
    end
    st = @inf.statement_for(@month)
    assert st.goal_met?
    assert_empty calls
    assert_equal 0, MonthlyStatement.payable.count
  end

  test "aprovar o mês renova o cupom uma vez e cria o a pagar com vencimento dia 10" do
    proof("feed").approve!(by: @admin)
    proof("stories", 2).approve!(by: @admin)
    st = @inf.statement_for(@month)
    fake, calls = fake_coupon(limit: 4)
    with_fake_coupon(fake) do
      st.approve!(by: @admin)
      st.increment_coupon!
    end
    assert st.approved?
    assert_equal 1000.to_d, st.amount_payable
    assert_equal Date.new(2026, 11, 10), st.due_on
    assert_equal "done", st.coupon_status
    assert_equal 4, st.coupon_usage_limit
    assert_equal 1, calls.size
    assert_includes MonthlyStatement.payable, st
  end

  test "aprovar com valor ajustado e sem renovar cupom" do
    st = @inf.statement_for(@month)
    fake, calls = fake_coupon
    with_fake_coupon(fake) { st.approve!(by: @admin, amount: "350.5", renew_coupon: false) }
    assert_equal 350.5.to_d, st.amount_payable
    assert_empty calls
  end

  test "reprovar não gera a pagar e reabrir remove o a pagar" do
    st = @inf.statement_for(@month)
    st.reject!(by: @admin, note: "sem marcação")
    assert st.rejected?
    assert_nil st.amount_payable

    with_fake_coupon(fake_coupon.first) { st.approve!(by: @admin, amount: 100) }
    st.reopen!
    assert st.review_open?
    assert_not_includes MonthlyStatement.payable, st
  end

  test "falha na Shopify fica registrada para tentar de novo" do
    st = @inf.statement_for(@month)
    with_fake_coupon(fake_coupon(error: "sem permissão").first) { st.approve!(by: @admin) }
    assert st.approved?
    assert_equal "error", st.coupon_status
    assert_equal "sem permissão", st.coupon_error
  end

  test "pagamento usa o valor aprovado" do
    st = @inf.statement_for(@month)
    with_fake_coupon(fake_coupon.first) { st.approve!(by: @admin, amount: 800) }
    st.mark_paid!(by: @admin)
    assert_equal 800.to_d, st.amount_paid
    assert_not_includes MonthlyStatement.payable, st
  end
end
