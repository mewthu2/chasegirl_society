# Usuário administrador inicial. Troque a senha em "Minha conta" depois do primeiro acesso.
User.find_or_create_by!(email_address: "danielkbr89@gmail.com") do |u|
  u.name = "Daniel Fernandes"
  u.role = "admin"
  u.password = ENV.fetch("ADMIN_PASSWORD", "admin@123")
end
