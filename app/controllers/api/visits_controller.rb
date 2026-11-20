module Api
  # POST /api/visits — visitas do app do iPhone (CLLocationManager, monitoramento
  # de visitas). Corpo: { "visits": [ { "external_id", "arrived_at", "departed_at",
  # "latitude", "longitude", "accuracy_m", "address" } ] }. Idempotente por
  # external_id: o iPhone reenvia a visita com a saída quando a pessoa vai embora.
  class VisitsController < BaseController
    after_action(only: :create) { record_ingestion("visits") }

    def create
      items = params[:visits]
      return render json: { error: "invalid_payload" }, status: :unprocessable_entity unless items.is_a?(Array)

      result = Places::Ingest.new(current_account, source: "iphone").call(items)
      @ingestion_result = result.to_h
      render json: { ok: true }.merge(result.to_h)
    end
  end
end
