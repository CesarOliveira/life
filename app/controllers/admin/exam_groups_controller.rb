module Admin
  # Catálogo de exames: grupos (painéis) e seus tipos. Nomes/descrições i18n.
  class ExamGroupsController < BaseController
    def index
      @groups = ExamGroup.ordered.includes(:exam_types)
    end

    def new
      @group = ExamGroup.new(position: ExamGroup.maximum(:position).to_i + 1)
    end

    def create
      @group = ExamGroup.new(group_params)
      if @group.save
        redirect_to admin_exam_groups_path, notice: t("admin.catalog.saved")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @group = ExamGroup.find(params[:id])
    end

    def update
      @group = ExamGroup.find(params[:id])
      if @group.update(group_params)
        redirect_to admin_exam_groups_path, notice: t("admin.catalog.saved")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def group_params
      params.require(:exam_group).permit(:key, :name_pt, :name_en, :description_pt, :description_en, :position)
    end
  end
end
