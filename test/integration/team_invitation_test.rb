require "test_helper"

class TeamInvitationTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "admin cadastra gerente, convite chega e ele cria a senha" do
    post session_path, params: { email_address: users(:admin).email_address, password: "password" }
    assert_emails 1 do
      post users_path, params: { user: { name: "Gerente Novo", email_address: "novo@chase.test", role: "manager" } }
    end
    user = User.find_by!(email_address: "novo@chase.test")
    assert user.manager?
    assert user.invitation_pending?

    delete session_path
    token = user.generate_token_for(:invitation)
    patch invitation_path(token), params: { user: { password: "segredo1", password_confirmation: "segredo1" } }
    assert_redirected_to root_path
    assert user.reload.activated?
    get influencers_path
    assert_response :success
  end
end
