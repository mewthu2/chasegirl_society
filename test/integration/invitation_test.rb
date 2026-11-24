require "test_helper"

class InvitationTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @inf = Influencer.create!(name: "Bia Souza", feed_goal: 1, stories_goal: 4, tiktok_goal: 0, cash_value: 1000)
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
  end

  def invite!
    assert_emails 1 do
      post access_influencer_path(@inf), params: { access: { email_address: "Bia@Email.test " } }
    end
    @inf.reload.user
  end

  test "cadastrar o e-mail cria pré-cadastro e envia o convite" do
    user = invite!
    assert_equal "bia@email.test", user.email_address
    assert user.invitation_pending?
    assert user.invited_at
    mail = ActionMailer::Base.deliveries.last
    assert_equal ["bia@email.test"], mail.to
    assert_match "/convite/", mail.text_part.body.to_s
  end

  test "ela cria a senha, completa os dados e entra; o link não vale de novo" do
    user = invite!
    token = user.generate_token_for(:invitation)
    delete session_path

    get invitation_path(token)
    assert_response :success

    patch invitation_path(token), params: { user: { password: "minha123", password_confirmation: "minha123" },
                                            influencer: { phone: "11 99999-0000", pix_key: "bia@pix", city: "SP" } }
    assert_redirected_to portal_path
    assert user.reload.activated?
    assert user.authenticate("minha123")
    assert_equal ["11 99999-0000", "bia@pix", "SP"], @inf.reload.then { [_1.phone, _1.pix_key, _1.city] }

    get invitation_path(token)
    assert_redirected_to new_session_path
  end

  test "senhas diferentes não ativam" do
    token = invite!.generate_token_for(:invitation)
    delete session_path
    patch invitation_path(token), params: { user: { password: "minha123", password_confirmation: "outra123" } }
    assert_response :unprocessable_entity
    assert @inf.reload.user.invitation_pending?
  end

  test "não entra antes de concluir o cadastro" do
    invite!
    delete session_path
    post session_path, params: { email_address: "bia@email.test", password: "" }
    assert_redirected_to new_session_path
  end

  test "reenviar convite manda novo e-mail" do
    invite!
    assert_emails(1) { post resend_invitation_influencer_path(@inf) }
  end
end
