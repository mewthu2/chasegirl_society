require "test_helper"

class PermissionsTest < ActionDispatch::IntegrationTest
  setup do
    @inf = Influencer.create!(name: "Ana", feed_goal: 1, stories_goal: 4, tiktok_goal: 1, cash_value: 1000)
  end

  def login(user)
    post session_path, params: { login: user.email_address, password: "password" }
  end

  test "gerente configura metas e valores" do
    login users(:manager)
    patch influencer_path(@inf), params: { influencer: { stories_goal: 6, cash_value: 1200 } }
    assert_equal [6, 1200.to_d], @inf.reload.then { [_1.stories_goal, _1.cash_value] }
  end

  test "admin também altera metas e valores" do
    login users(:admin)
    patch influencer_path(@inf), params: { influencer: { stories_goal: 6, cash_value: 1200, city: "BH" } }
    @inf.reload
    assert_equal [6, 1200.to_d, "BH"], [@inf.stories_goal, @inf.cash_value, @inf.city]
  end

  test "admin cadastra nova influenciadora com contrato" do
    login users(:admin)
    get influencers_path
    assert_select "a[href=?]", new_influencer_path
    get new_influencer_path
    assert_response :success
    assert_difference "Influencer.count", 1 do
      post influencers_path, params: { influencer: { name: "Bia", instagram: "@bia.chase", city: "SP", cash_value: 5000, coupon_code: "CGBIA" } }
    end
    bia = Influencer.order(:id).last
    assert_redirected_to influencer_path(bia)
    assert_equal ["bia.chase", "SP", 5000.to_d, "CGBIA"], [bia.instagram, bia.city, bia.cash_value, bia.coupon_code]
  end

  test "gerente cadastra nova influenciadora com contrato" do
    login users(:manager)
    assert_difference "Influencer.count", 1 do
      post influencers_path, params: { influencer: { name: "Carol", instagram: "carol", cash_value: 1200, coupon_code: "cgcarol" } }
    end
    assert_equal [1200.to_d, "CGCAROL"], Influencer.order(:id).last.then { [_1.cash_value, _1.coupon_code] }
  end

  test "gerente vê o a pagar mas não os pagos nem registra pagamento" do
    login users(:manager)
    get statements_path
    assert_response :success
    get paid_statements_path
    assert_redirected_to root_path
    st = @inf.statement_for(Date.new(2026, 10, 1))
    st.update!(review_status: "approved", amount_payable: 500)
    post pay_statement_path(st)
    assert_not st.reload.paid?
  end

  test "não aprova mês ainda em andamento" do
    login users(:manager)
    st = @inf.statement_for(Date.current)
    post approve_review_path(st)
    assert st.reload.review_open?
  end

  test "gerente não gerencia equipe; admin sim" do
    login users(:manager)
    get users_path
    assert_redirected_to root_path
    login users(:admin)
    get users_path
    assert_response :success
  end

  test "influenciadora não acessa telas da equipe" do
    user = @inf.create_user!(email_address: "ana@x.test", password: "password", role: "influencer", activated_at: Time.current)
    login user
    [root_path, reviews_path, statements_path, influencers_path].each do |path|
      get path
      assert_redirected_to portal_path, path
    end
  end
end
