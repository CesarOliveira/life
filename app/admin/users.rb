ActiveAdmin.register User do
  # Filtros enxutos (sem auto-gerar todos). Adicionar mais conforme necessidade.
  filter :name
  filter :created_at
  filter :updated_at
end
