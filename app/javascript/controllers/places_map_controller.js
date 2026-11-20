import { Controller } from "@hotwired/stimulus"
import L from "leaflet"

// Mapa do dia: um círculo por lugar visitado (tamanho pelo tempo) e uma linha
// tracejada ligando as visitas na ordem do dia. Tiles do OpenStreetMap.
export default class extends Controller {
  static values = { points: Array }

  connect() {
    const points = this.pointsValue
    this.map = L.map(this.element, { scrollWheelZoom: false, attributionControl: true })
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(this.map)

    if (points.length === 0) {
      this.map.setView([-14.2, -51.9], 3)
      return
    }

    const latlngs = points.map(p => [p.lat, p.lng])
    if (latlngs.length > 1) {
      L.polyline(latlngs, { color: "#64748b", weight: 2, dashArray: "4 6", opacity: 0.8 }).addTo(this.map)
    }
    points.forEach((p, i) => {
      const radius = Math.max(6, Math.min(16, 5 + Math.sqrt(p.minutes || 0)))
      L.circleMarker([p.lat, p.lng], {
        radius, color: "#ffffff", weight: 2, fillColor: p.named ? "#059669" : "#f59e0b", fillOpacity: 0.95
      }).addTo(this.map).bindTooltip(`${i + 1}. ${this.escape(p.name)} · ${p.label}`)
    })
    this.map.fitBounds(L.latLngBounds(latlngs).pad(0.25), { maxZoom: 16 })
  }

  disconnect() {
    if (this.map) this.map.remove()
  }

  escape(text) {
    const div = document.createElement("div")
    div.textContent = text || ""
    return div.innerHTML
  }
}
