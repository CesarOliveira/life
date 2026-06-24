class SeedRolesAndBootstrapAdmins < ActiveRecord::Migration[8.1]
  # Migration de DADOS: cria as roles base e concede admin + super_admin aos
  # e-mails de PLATFORM_ADMIN_EMAILS (bootstrap do 1º admin no deploy). Idempotente.
  def up
    admin = Role.find_or_create_by!(name: "admin")       { |r| r.description = "Administrador da plataforma" }
    sa    = Role.find_or_create_by!(name: "super_admin")  { |r| r.description = "Super administrador (ActiveAdmin)" }
    Role.find_or_create_by!(name: "member") { |r| r.description = "Usuário comum" }

    emails = ENV.fetch("PLATFORM_ADMIN_EMAILS", "").split(",").map { |e| e.strip.downcase }.reject(&:blank?)
    if emails.empty?
      say "Bootstrap: PLATFORM_ADMIN_EMAILS vazio, nada a fazer"
      return
    end

    granted = 0
    User.where("lower(email) IN (?)", emails).find_each do |u|
      [admin, sa].each do |role|
        next if u.roles.exists?(id: role.id)
        u.roles << role
        granted += 1
      end
    end
    say "Bootstrap: #{granted} role(s) concedida(s) a partir de PLATFORM_ADMIN_EMAILS"
  end

  def down
    Role.where(name: %w[admin super_admin member]).destroy_all
  end
end
