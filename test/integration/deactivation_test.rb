require "test_helper"

# Desligar influenciadora: só a equipe faz; ela perde o acesso na hora (inclusive a sessão aberta) e o
# histórico fica. Reativar devolve o acesso com a mesma senha.
class DeactivationTest < ActionDispatch::IntegrationTest
  setup do
    @inf = Influencer.create!(name: "Ana", feed_goal: 1, stories_goal: 4, tiktok_goal: 1, cash_value: 1000)
    @user = @inf.create_user!(email_address: "ana@x.test", password: "password", role: "influencer", activated_at: Time.current)
  end

  def login(user)
    post session_path, params: { login: user.email_address, password: "password" }
  end

  test "a equipe desliga: a sessão aberta dela cai e ela não entra mais" do
    login @user
    get portal_path
    assert_response :success

    other = open_session
    other.post session_path, params: { login: users(:manager).email_address, password: "password" }
    other.delete influencer_path(@inf)
    assert_not @inf.reload.active?

    get portal_path
    assert_redirected_to new_session_path

    login @user
    assert_redirected_to new_session_path
    assert_equal ApplicationController::BLOCKED_MESSAGE, flash[:alert]
    assert_equal 0, @user.sessions.count
  end

  test "desmarcar Parceria ativa no cadastro também desliga" do
    login @user
    @inf.update!(active: false)

    get portal_path
    assert_redirected_to new_session_path
  end

  test "reativar devolve o acesso com a mesma senha" do
    @inf.deactivate!
    login users(:admin)
    get influencer_path(@inf)
    assert_select "form[action='#{reactivate_influencer_path(@inf)}']"

    post reactivate_influencer_path(@inf)
    assert @inf.reload.active?

    login @user
    assert_redirected_to root_url
    follow_redirect!
    assert_redirected_to portal_path
  end

  test "a página dela tem Desligar para a equipe" do
    login users(:manager)
    get influencer_path(@inf)
    assert_select "form[action='#{influencer_path(@inf)}'] button", text: /Desligar/
  end

  test "a influenciadora não consegue desligar nem reativar ninguém" do
    other = Influencer.create!(name: "Bia", feed_goal: 1, stories_goal: 1, tiktok_goal: 0, cash_value: 500, active: false)
    login @user

    delete influencer_path(@inf)
    assert_redirected_to portal_path
    post reactivate_influencer_path(other)
    assert_redirected_to portal_path
    assert @inf.reload.active?
    assert_not other.reload.active?
  end

  test "convite de influenciadora desligada não abre" do
    @user.update!(activated_at: nil)
    @inf.deactivate!

    get invitation_path(@user.generate_token_for(:invitation))
    assert_redirected_to new_session_path
  end

  test "o histórico continua: a conferência do mês já aprovado ainda aparece" do
    month = Date.new(2026, 10, 1)
    @inf.statement_for(month).update!(review_status: "approved", amount_payable: 500)
    @inf.deactivate!
    login users(:manager)

    get reviews_path(mes: "2026-10")
    assert_select "td", text: /Ana/
  end
end
