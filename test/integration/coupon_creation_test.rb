require "test_helper"

class CouponCreationTest < ActionDispatch::IntegrationTest
  def login(user)
    post session_path, params: { login: user.email_address, password: "password" }
  end

  def with_fake_shopify(result: :created, error: nil)
    calls = []
    fake = Object.new
    fake.define_singleton_method(:create!) do |amount:, usage_limit: 1|
      calls << { amount:, usage_limit: }
      error ? raise(ShopifyCoupon::Error, error) : result
    end
    codes = []
    ShopifyCoupon.define_singleton_method(:new) { |code| codes << code; fake }
    yield calls, codes
  ensure
    ShopifyCoupon.singleton_class.send(:remove_method, :new)
  end

  test "cadastrar influenciadora cria o cupom na Shopify com 1 uso no valor da permuta" do
    login users(:manager)
    with_fake_shopify do |calls, codes|
      post influencers_path, params: { influencer: { name: "Bia", instagram: "bia", cash_value: 1000, permuta_value: 1500, coupon_code: "cgbia" } }
      assert_equal ["CGBIA"], codes
      assert_equal [{ amount: 1500.to_d, usage_limit: 1 }], calls
    end
    follow_redirect!
    assert_match "criado na Shopify com 1 uso", flash[:notice]
  end

  test "falha na Shopify não impede o cadastro e avisa" do
    login users(:manager)
    with_fake_shopify(error: "sem permissão") do
      assert_difference("Influencer.count", 1) do
        post influencers_path, params: { influencer: { name: "Bia", instagram: "bia", coupon_code: "CGBIA" } }
      end
    end
    assert_match "NÃO foi criado na Shopify: sem permissão", flash[:alert]
  end

  test "editar sem trocar o cupom não chama a Shopify" do
    inf = Influencer.create!(name: "Ana", feed_goal: 1, stories_goal: 4, tiktok_goal: 1, cash_value: 1000, coupon_code: "CGANA")
    login users(:manager)
    with_fake_shopify do |calls, _|
      patch influencer_path(inf), params: { influencer: { stories_goal: 6 } }
      assert_empty calls
      patch influencer_path(inf), params: { influencer: { coupon_code: "CGANA2" } }
      assert_equal 1, calls.size
    end
  end

  test "meta é por mês, sem vigência: vale a partir do mês do cadastro enquanto ativa" do
    inf = Influencer.create!(name: "Ana", feed_goal: 1, stories_goal: 0, tiktok_goal: 0, cash_value: 1000, created_at: Date.new(2026, 11, 20))
    assert_not inf.active_in?(Date.new(2026, 10, 1))
    assert inf.active_in?(Date.new(2026, 11, 1))
    assert inf.active_in?(Date.new(2027, 6, 1))
    inf.update!(active: false)
    assert_not inf.active_in?(Date.new(2026, 12, 1))
  end
end
