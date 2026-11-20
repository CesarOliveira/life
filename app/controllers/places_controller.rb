# Linha do tempo de lugares: o dia num mapa com as visitas e o tempo em cada
# lugar; "Meus lugares" para nomear, ajustar o raio e importar a Linha do Tempo
# do Google. As coordenadas são criptografadas no banco (ver GeoPoint).
class PlacesController < ApplicationController
  before_action :set_place, only: [:update, :destroy]

  def index
    @date = parse_date(params[:dia]) || Date.current
    @timeline = Places::Timeline.new(current_account, @date)
    @has_any = current_account.visits.exists?
    @last_day = current_account.visits.maximum(:date)
  end

  def manage
    @places = current_account.places.ordered.to_a
    @stats = Places::Stats.new(current_account, from: 29.days.ago.to_date, to: Date.current).rows.index_by(&:place)
    @suggestions = Places::Suggestions.new(current_account).call
    @visit_count = current_account.visits.count
    @first_day, @last_day = current_account.visits.pick(Arel.sql("MIN(date)"), Arel.sql("MAX(date)"))
  end

  def create
    place = current_account.places.new(place_params)
    if place.save
      Places::Matcher.new(current_account).assign_unassigned
      Places::HabitRefresh.full(current_account)
      redirect_back_or_to manage_places_path, notice: t("flash.places.created", name: place.name)
    else
      redirect_back_or_to manage_places_path, alert: place.errors.full_messages.to_sentence
    end
  end

  def update
    if @place.update(place_params.slice(:name, :radius_m))
      if @place.saved_change_to_radius_m?
        Places::Matcher.new(current_account).reassign_all
        Places::HabitRefresh.full(current_account)
      end
      redirect_to manage_places_path, notice: t("flash.places.updated")
    else
      redirect_to manage_places_path, alert: @place.errors.full_messages.to_sentence
    end
  end

  def destroy
    id = @place.id
    @place.destroy
    current_account.habits.where("? = ANY(place_ids)", id).find_each { |h| h.update_columns(place_ids: h.place_ids - [id]) }
    redirect_to manage_places_path, notice: t("flash.places.removed")
  end

  # POST /lugares/importar (JSON) — lotes de visitas já extraídas no navegador.
  def import
    result = Places::Ingest.new(current_account, source: "google").call(params.fetch(:visits, []))
    render json: result.to_h
  end

  def destroy_day
    date = parse_date(params[:dia])
    current_account.visits.where(date: date).delete_all if date
    redirect_to places_path(dia: date), notice: t("flash.places.day_removed")
  end

  def destroy_history
    current_account.visits.delete_all
    redirect_to manage_places_path, notice: t("flash.places.history_removed")
  end

  private

  def set_place
    @place = current_account.places.find(params[:id])
  end

  def place_params
    params.require(:place).permit(:name, :latitude, :longitude, :radius_m, :address)
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end
end
