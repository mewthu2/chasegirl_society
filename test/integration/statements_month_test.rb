require "test_helper"

# A pagar filtrado por mês de competência, como a Conferência (padrão: o mês em conferência).
class StatementsMonthTest < ActionDispatch::IntegrationTest
  setup do
    @ana = Influencer.create!(name: "Ana", feed_goal: 1, stories_goal: 4, tiktok_goal: 1, cash_value: 1000)
    @bia = Influencer.create!(name: "Bia", feed_goal: 1, stories_goal: 4, tiktok_goal: 0, cash_value: 800)
    @review = MonthlyStatement.review_month
    approve(@ana, @review, 1000)
    approve(@bia, @review.prev_month, 800)
    post session_path, params: { login: users(:admin).email_address, password: "password" }
  end

  def approve(inf, month, amount)
    inf.statement_for(month).update!(review_status: "approved", amount_payable: amount, due_on: MonthlyStatement.due_date(month))
  end

  test "sem mês escolhido mostra o mês em conferência, com o seletor de mês e o aviso dos outros meses" do
    get statements_path

    assert_select "h1", text: /A pagar · /
    assert_select ".month-switch .month-current"
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /Ana/
    assert_select ".callout a[href='#{statements_path(mes: @review.prev_month.strftime('%Y-%m'))}']", text: /\(1\)/
  end

  test "escolhendo o mês, mostra só os daquele mês, e o CSV segue o mês" do
    get statements_path(mes: @review.prev_month.strftime("%Y-%m"))
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /Bia/

    get statements_path(mes: @review.prev_month.strftime("%Y-%m"), format: :csv)
    assert_includes response.body, "Bia"
    assert_not_includes response.body, "Ana"
  end

  test "mês sem nada a pagar avisa" do
    get statements_path(mes: "2020-01")
    assert_select ".empty", text: /Nada a pagar em/
  end
end
