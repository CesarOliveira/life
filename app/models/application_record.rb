class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Ransack (usado pelos filtros do ActiveAdmin) exige allowlist explícita de
  # atributos/associações pesquisáveis. Liberamos todos porque o ActiveAdmin é
  # restrito a super_admins (já gateado em authenticate_super_admin!), então não
  # há exposição de busca a usuários não-confiáveis.
  def self.ransackable_attributes(_auth_object = nil)
    column_names + _ransackers.keys
  end

  def self.ransackable_associations(_auth_object = nil)
    reflect_on_all_associations.map { |a| a.name.to_s }
  end
end
