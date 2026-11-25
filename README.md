# Chase Society

Painel das parceiras Chase Brasil: influenciadoras enviam a prova dos stories, posts e TikToks; a equipe aprova;
o sistema calcula o cachê do mês e libera +1 uso no cupom da Shopify quando a meta é batida.

## Regras
- **Metas por canal** (Feed/Reels, Stories, TikTok) definidas por influenciadora. Meta 0 = canal não contratado.
- **Cachê (valor do PIX)** dividido igualmente entre os canais contratados: com TikTok 33,33% cada, sem TikTok 50% cada.
  Cada canal cumprido no mês (comprovações aprovadas ≥ meta) libera a sua parte.
- **Permuta** = valor do cupom. Quando todas as metas do mês são batidas, o `usageLimit` do código de desconto
  na Shopify aumenta em 1 (uma vez por mês). Se falhar, o botão "Liberar cupom" em Financeiro › A pagar tenta de novo.
- **Comprovação** é por mês de referência (o atual ou o anterior, enquanto não aprovado). Feed = link; Stories = print; TikTok = link e print. A influenciadora envia em "Enviar comprovação"; a "Minha área" é só o painel.
- **Pré-cadastro**: na ficha da influenciadora a equipe informa só o e-mail; ela recebe um convite (vale 7 dias, uso único)
  para criar a senha e completar telefone, cidade e PIX. "Reenviar convite" na ficha; depois de ativa, vira "enviar link de nova senha".
- **Esqueci minha senha** no login, com link por e-mail.
- **Financeiro › A pagar**: valor liberado por mês, marcar como pago, exportar CSV.

## Configuração (Heroku)
| Variável | Para quê |
|---|---|
| `SECRET_KEY_BASE` | sessões |
| `SHOPIFY_ACCESS_TOKEN` | token Admin API com `read_discounts` e `write_discounts` |
| `SHOPIFY_SHOP` | padrão `chasebrasil.myshopify.com` |
| `AWS_SES_ACCESS_KEY_ID`, `AWS_SES_SECRET_ACCESS_KEY`, `AWS_SES_REGION`, `MAILER_FROM` | e-mails pelo Amazon SES (mesma conta do chase-orders, domínio chasebrasil.com) |
| `BUCKETEER_*` | criadas pelo add-on Bucketeer: os prints ficam nesse bucket S3 (sem ele, caem no Postgres) |

## Comandos
```
bin/rails db:seed                              # cria o admin inicial
bin/rails "import:influencers[planilha.csv]"   # importa a aba chasegirl_society exportada em CSV
bin/rails test
```
