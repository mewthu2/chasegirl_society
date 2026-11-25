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

  test "admin não altera metas e valores, só dados cadastrais" do
    login users(:admin)
    patch influencer_path(@inf), params: { influencer: { stories_goal: 6, cash_value: 1200, city: "BH" } }
    @inf.reload
    assert_equal [4, 1000.to_d, "BH"], [@inf.stories_goal, @inf.cash_value, @inf.city]
    get new_influencer_path
    assert_redirected_to root_path
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
