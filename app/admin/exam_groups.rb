# frozen_string_literal: true

ActiveAdmin.register ExamGroup do
  permit_params :key, :name_pt, :name_en, :description_pt, :description_en, :position

  index do
    selectable_column
    id_column
    column :key
    column :name_pt
    column :name_en
    column :position
    column(proc { I18n.t("admin.catalog.types_count") }) { |g| g.exam_types.size }
    actions
  end

  form do |f|
    f.inputs do
      f.input :key
      f.input :name_pt
      f.input :name_en
      f.input :description_pt
      f.input :description_en
      f.input :position
    end
    f.actions
  end
end
