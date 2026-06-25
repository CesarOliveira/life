class RebootstrapPlatformAdmins < ActiveRecord::Migration[8.1]
  # Reconcede admin + super_admin aos e-mails de PLATFORM_ADMIN_EMAILS para
  # usuários que JÁ existiam (a bootstrap original roda só uma vez, e pode não
  # ter pego quem se cadastrou depois). Idempotente.
  def up
    emails = User.platform_admin_emails
    return if emails.empty?

    admin = Role.find_or_create_by!(name: Role::ADMIN)
    sa    = Role.find_or_create_by!(name: Role::SUPER_ADMIN)

    User.where("lower(email) IN (?)", emails).find_each do |u|
      u.roles << admin unless u.roles.exists?(id: admin.id)
      u.roles << sa unless u.roles.exists?(id: sa.id)
    end
  end

  def down
  end
end
