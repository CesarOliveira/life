module Admin
  # Tipos de exame (itens do catálogo): key, nomes/descrições i18n, grupo, apelidos.
  class ExamTypesController < BaseController
    def new
      @type = ExamType.new(exam_group_id: params[:exam_group_id])
    end

    def create
      @type = ExamType.new(type_params)
      if @type.save
        redirect_to admin_exam_groups_path, notice: t("admin.catalog.saved")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @type = ExamType.find(params[:id])
    end

    def update
      @type = ExamType.find(params[:id])
      if @type.update(type_params)
        redirect_to admin_exam_groups_path, notice: t("admin.catalog.saved")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      type = ExamType.find(params[:id])
      if type.exam_results.exists?
        redirect_to admin_exam_groups_path, alert: t("admin.catalog.has_results")
      else
        type.destroy
        redirect_to admin_exam_groups_path, notice: t("admin.catalog.removed")
      end
    end

    private

    def type_params
      permitted = params.require(:exam_type)
                        .permit(:exam_group_id, :key, :name_pt, :name_en, :description_pt, :description_en, :position, :aliases_text)
      aliases_text = permitted.delete(:aliases_text)
      permitted[:aliases] = aliases_text.to_s.split(/[,;\n]/).map(&:strip).reject(&:blank?).uniq if aliases_text
      permitted
    end
  end
end
