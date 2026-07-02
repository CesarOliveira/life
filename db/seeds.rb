puts "Seeding..."

# Roles base
Role.find_or_create_by!(name: Role::ADMIN)       { |r| r.description = "Administrador da plataforma" }
Role.find_or_create_by!(name: Role::SUPER_ADMIN) { |r| r.description = "Super administrador (ActiveAdmin)" }
Role.find_or_create_by!(name: Role::MEMBER)      { |r| r.description = "Usuário comum" }

# Catálogo de exames (só quando vazio — o admin é a fonte da verdade depois)
if ExamGroup.none?
  require_relative "exam_catalog_data"
  EXAM_CATALOG_DATA.each_with_index do |(gkey, gpt, gen, types), gi|
    group = ExamGroup.create!(key: gkey, name_pt: gpt, name_en: gen, position: gi)
    types.each_with_index do |(key, name_pt, name_en, aliases, extra_alias), ti|
      ExamType.create!(exam_group: group, key: key, name_pt: name_pt, name_en: name_en,
                       aliases: (aliases + [extra_alias]).compact.uniq, position: ti)
    end
  end
  puts "Exam catalog seeded (#{ExamType.count} types)"
end

# Usuário/conta de exemplo (somente dev)
if Rails.env.development?
  dev_user = User.find_or_create_by(email: "dev@example.com") do |u|
    u.name = "Dev User"
    u.password = "password123"
    u.password_confirmation = "password123"
  end

  dev_account = Account.find_or_create_by(owner: dev_user) do |a|
    a.name = "Conta Dev"
  end
  Membership.find_or_create_by(user: dev_user, account: dev_account) do |m|
    m.role = "owner"
    m.status = "active"
  end

  # Dev user é admin e super_admin (acessa /admin e /super_admin)
  dev_user.add_role(Role::ADMIN)
  dev_user.add_role(Role::SUPER_ADMIN)
end

puts "Done!"
