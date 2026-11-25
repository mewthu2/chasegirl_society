require "test_helper"

# Minha área é só o painel; o envio é em "Enviar comprovação", escolhendo o mês de referência.
class ProofSubmissionTest < ActionDispatch::IntegrationTest
  setup do
    @inf = Influencer.create!(name: "Ana", feed_goal: 1, stories_goal: 4, tiktok_goal: 1, cash_value: 1000)
    @user = @inf.create_user!(email_address: "ana@x.test", password: "password", role: "influencer", activated_at: Time.current)
    post session_path, params: { login: @user.email_address, password: "password" }
  end

  test "minha área não tem envio" do
    get portal_path
    assert_response :success
    assert_select "form input[type=file]", 0
    assert_select "#comprovar", 0
  end

  test "envia comprovação de feed só com link, sempre para o mês atual" do
    current = Date.current.beginning_of_month
    get new_proof_path
    assert_response :success
    assert_select "input[type=hidden][name='proof[month]'][value='#{current}']"

    post proofs_path, params: { proof: { kind: "feed", month: current.prev_month.to_s, link: "instagram.com/p/abc" } }
    assert_response :unprocessable_entity

    post proofs_path, params: { proof: { kind: "feed", month: current.to_s, link: "instagram.com/p/abc" } }
    assert_equal current, @inf.proofs.last.month
    assert_redirected_to portal_path(mes: current.strftime("%Y-%m"))
  end

  test "mês já cumprido: tela avisa que o próximo envio é no mês seguinte" do
    @inf.statement_for(Date.current).update_columns(review_status: "approved")
    get new_proof_path
    assert_select ".callout", text: /já foram cumpridas/
    assert_select "input[name='proof[month]']", 0
  end

  test "stories sem print não vai" do
    post proofs_path, params: { proof: { kind: "stories", month: Date.current.beginning_of_month.to_s } }
    assert_response :unprocessable_entity
    assert_equal 0, @inf.proofs.count
  end
end
