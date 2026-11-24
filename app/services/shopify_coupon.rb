require "net/http"

# Lê e ajusta o "número máximo de usos" de um cupom (código de desconto) na Shopify.
# Precisa de SHOPIFY_ACCESS_TOKEN com os escopos read_discounts e write_discounts.
class ShopifyCoupon
  class Error < StandardError; end

  API_VERSION = "2025-10".freeze
  UPDATE_MUTATIONS = {
    "DiscountCodeBasic" => %w[discountCodeBasicUpdate basicCodeDiscount DiscountCodeBasicInput],
    "DiscountCodeBxgy" => %w[discountCodeBxgyUpdate bxgyCodeDiscount DiscountCodeBxgyInput],
    "DiscountCodeFreeShipping" => %w[discountCodeFreeShippingUpdate freeShippingCodeDiscount DiscountCodeFreeShippingInput]
  }.freeze

  LOOKUP = <<~GQL.freeze
    query($code: String!) {
      codeDiscountNodeByCode(code: $code) {
        id
        codeDiscount {
          __typename
          ... on DiscountCodeBasic { title status usageLimit asyncUsageCount }
          ... on DiscountCodeBxgy { title status usageLimit asyncUsageCount }
          ... on DiscountCodeFreeShipping { title status usageLimit asyncUsageCount }
        }
      }
    }
  GQL

  def self.configured? = ENV["SHOPIFY_ACCESS_TOKEN"].present?

  def initialize(code)
    @code = code.to_s.strip
  end

  # => { id:, type:, title:, status:, usage_limit:, used: }
  def lookup
    node = graphql(LOOKUP, code: @code).dig("codeDiscountNodeByCode")
    raise Error, "Cupom #{@code} não encontrado na Shopify" unless node
    discount = node["codeDiscount"] || {}
    {
      id: node["id"], type: discount["__typename"], title: discount["title"], status: discount["status"],
      usage_limit: discount["usageLimit"], used: discount["asyncUsageCount"]
    }
  end

  def increment_usage_limit!(by: 1)
    info = lookup
    mutation, arg, input_type = UPDATE_MUTATIONS[info[:type]]
    raise Error, "Tipo de cupom #{info[:type]} não suportado" unless mutation
    raise Error, "Cupom #{@code} está sem limite de usos na Shopify (ilimitado)" if info[:usage_limit].nil?

    new_limit = info[:usage_limit].to_i + by
    query = <<~GQL
      mutation($id: ID!, $input: #{input_type}!) {
        #{mutation}(id: $id, #{arg}: $input) { userErrors { field message } }
      }
    GQL
    errors = graphql(query, id: info[:id], input: { usageLimit: new_limit }).dig(mutation, "userErrors")
    raise Error, errors.map { _1["message"] }.join("; ") if errors.present?
    new_limit
  end

  private

  def graphql(query, variables)
    raise Error, "Integração Shopify não configurada (SHOPIFY_ACCESS_TOKEN)" unless self.class.configured?

    shop = ENV.fetch("SHOPIFY_SHOP", "chasebrasil.myshopify.com")
    uri = URI("https://#{shop}/admin/api/#{API_VERSION}/graphql.json")
    req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json", "X-Shopify-Access-Token" => ENV["SHOPIFY_ACCESS_TOKEN"])
    req.body = { query:, variables: }.to_json
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 8, read_timeout: 15) { _1.request(req) }
    raise Error, "Shopify respondeu HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)

    body = JSON.parse(res.body)
    raise Error, body["errors"].map { _1["message"] }.join("; ") if body["errors"].present?
    body["data"]
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED => e
    raise Error, "Falha ao falar com a Shopify: #{e.message}"
  end
end
