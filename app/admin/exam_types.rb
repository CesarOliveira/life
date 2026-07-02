# frozen_string_literal: true

ActiveAdmin.register ExamType do
  permit_params :exam_group_id, :key, :name_pt, :name_en, :description_pt, :description_en, :position, aliases: []

  index do
    selectable_column
    id_column
    column :exam_group
    column :key
    column :name_pt
    column :name_en
    column("Apelidos") { |t| t.aliases.join(", ").truncate(50) }
    column :position
    actions
  end

  form do |f|
    f.inputs do
      f.input :exam_group
      f.input :key
      f.input :name_pt
      f.input :name_en
      f.input :description_pt
      f.input :description_en
      # Apelidos como texto separado por vírgula (array no banco).
      f.input :aliases_text, label: "Aliases (separados por vírgula)",
                             input_html: { value: f.object.aliases.join(", "), name: "exam_type[aliases_text]" },
                             as: :string
      f.input :position
    end
    f.actions
  end

  controller do
    def update
      coerce_aliases
      super
    end

    def create
      coerce_aliases
      super
    end

    private

    def coerce_aliases
      text = params.dig(:exam_type, :aliases_text)
      return if text.nil?

      params[:exam_type][:aliases] = text.split(/[,;\n]/).map(&:strip).reject(&:blank?).uniq
    end
  end
end
