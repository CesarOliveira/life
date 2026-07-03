# Favoritar um grupo de exames: grupos favoritos aparecem no topo da aba Exames.
class ExamGroupFavoritesController < ApplicationController
  def toggle
    group = ExamGroup.find(params[:id])
    group.update!(favorite: !group.favorite)
    redirect_to measurements_path(category: "exam")
  end
end
