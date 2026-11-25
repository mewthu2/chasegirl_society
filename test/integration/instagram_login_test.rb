require "test_helper"

# Login por e-mail ou @ e primeiro acesso da influenciadora pelo @.
class InstagramLoginTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @inf = Influencer.create!(name: "Ana Menezes", instagram: "anamflima", feed_goal: 1, stories_goal: 4, tiktok_goal: 0, cash_value: 1000)
  end

  def first_access!(email: "ana@email.test", password: "segredo1")
    post first_access_path, params: { instagram: "@AnamFlima" }
    assert_response :success
    assert_match "Ana", response.body
    assert_emails 1 do
      post first_access_register_path, params: { instagram: "anamflima", email_address: email, password:, password_confirmation: password }
    end
    @inf.reload.user
  end

  test "primeiro acesso: digita o @, informa e-mail e senha, confirma pelo link e entra" do
    user = first_access!
    assert_equal "ana@email.test", user.email_address
    assert_not user.activated?

    post session_path, params: { login: "anamflima", password: "segredo1" }
    assert_redirected_to new_session_path(login: "anamflima")
    assert_match "confirmar seu e-mail", flash[:alert]

    get first_access_confirm_path(user.generate_token_for(:email_confirmation))
    assert_redirected_to portal_path
    assert user.reload.activated?
  end

  test "depois de ativa entra pelo @ (com ou sem arroba, qualquer caixa) ou pelo e-mail" do
    user = first_access!
    user.update!(activated_at: Time.current)
    ["anamflima", "@AnamFlima", "ana@email.test"].each do |login|
      reset!
      post session_path, params: { login:, password: "segredo1" }
      assert_redirected_to root_path, login
    end
  end

  test "@ inexistente não acha cadastro" do
    post first_access_path, params: { instagram: "naoexiste" }
    assert_redirected_to first_access_path(instagram: "naoexiste")
  end

  test "quem já tem acesso é mandada para o login" do
    first_access!.update!(activated_at: Time.current)
    post first_access_path, params: { instagram: "anamflima" }
    assert_redirected_to new_session_path(login: "anamflima")
  end

  test "refazer o primeiro acesso com outro e-mail invalida o link antigo" do
    user = first_access!
    old_token = user.generate_token_for(:email_confirmation)
    first_access!(email: "certo@email.test")
    get first_access_confirm_path(old_token)
    assert_redirected_to new_session_path
    assert_not user.reload.activated?
  end

  test "influenciadora desligada não faz primeiro acesso" do
    @inf.update!(active: false)
    post first_access_path, params: { instagram: "anamflima" }
    assert_redirected_to first_access_path(instagram: "anamflima")
  end

  test "@ é único sem diferenciar maiúsculas" do
    dup = Influencer.new(name: "Outra", instagram: "@ANAMFLIMA", feed_goal: 1, stories_goal: 0, tiktok_goal: 0)
    assert_not dup.valid?
    assert dup.errors[:instagram].any?
  end

  test "esqueci a senha aceita o @" do
    first_access!.update!(activated_at: Time.current)
    assert_emails(1) { post passwords_path, params: { login: "@anamflima" } }
  end
end
