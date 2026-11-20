import { Controller } from "@hotwired/stimulus"
import L from "leaflet"

// Mapa do dia: marcadores numerados (os mesmos números da lista), linha tracejada
// ligando as visitas na ordem do dia, tela cheia e "ajustar ao dia". A roda do
// mouse só dá zoom depois de clicar no mapa (para não prender a rolagem da página).
// Tocar num item da lista centraliza o mapa nele. Tiles do OpenStreetMap.
export default class extends Controller {
  static targets = ["canvas", "frame", "hint", "fullscreenLabel"]
  static values = { points: Array }

  connect() {
    this.markers = []
    const points = this.pointsValue
    this.map = L.map(this.canvasTarget, { scrollWheelZoom: false, zoomControl: true })
    L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
    }).addTo(this.map)

    // Roda do mouse: liga ao clicar no mapa, desliga ao sair dele.
    this.map.on("click focus", () => this.enableWheel())
    this.canvasTarget.addEventListener("mouseleave", () => {
      if (!this.frameTarget.classList.contains("places-map-full")) this.map.scrollWheelZoom.disable()
    })
    this.onKey = e => { if (e.key === "Escape" && this.frameTarget.classList.contains("places-map-full")) this.toggleFullscreen() }
    document.addEventListener("keydown", this.onKey)

    if (points.length === 0) {
      this.map.setView([-14.2, -51.9], 3)
      return
    }

    const latlngs = points.map(p => [p.lat, p.lng])
    if (latlngs.length > 1) {
      L.polyline(latlngs, { color: "#64748b", weight: 2, dashArray: "4 6", opacity: 0.8 }).addTo(this.map)
    }
    // Visitas ao mesmo ponto (ex.: Casa de manhã e à noite) viram um só marcador "1·3·5".
    const groups = []
    points.forEach((p, i) => {
      let g = groups.find(x => Math.abs(x.lat - p.lat) < 0.0003 && Math.abs(x.lng - p.lng) < 0.0003)
      if (!g) { g = { lat: p.lat, lng: p.lng, named: p.named, items: [] }; groups.push(g) }
      g.items.push({ ...p, n: i + 1 })
    })
    groups.forEach(g => {
      const label = g.items.map(x => x.n).join("·")
      const width = Math.max(26, 12 + label.length * 7)
      const icon = L.divIcon({
        className: "",
        html: `<span style="display:flex;align-items:center;justify-content:center;min-width:26px;width:${width}px;height:26px;border-radius:9999px;` +
              `background:${g.named ? "#059669" : "#f59e0b"};color:#fff;font:600 12px system-ui;border:2px solid #fff;` +
              `box-shadow:0 1px 4px rgba(15,23,42,.35)">${label}</span>`,
        iconSize: [width, 26],
        iconAnchor: [width / 2, 13]
      })
      const marker = L.marker([g.lat, g.lng], { icon, riseOnHover: true }).addTo(this.map)
      const lines = g.items.map(x => `${x.n}. ${this.escape(x.name)} · ${x.label}`).join("<br>")
      marker.bindTooltip(lines, { direction: "top", offset: [0, -12] })
      g.items.forEach(x => { this.markers[x.n - 1] = marker })
    })
    this.fit()
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKey)
    document.body.style.overflow = ""
    if (this.map) this.map.remove()
  }

  // Botão "Ajustar ao dia".
  fit() {
    if (this.pointsValue.length === 0) return
    const bounds = L.latLngBounds(this.pointsValue.map(p => [p.lat, p.lng]))
    this.map.fitBounds(bounds.pad(0.25), { maxZoom: 16 })
  }

  // Item da lista: centraliza e mostra o nome. data-places-map-index-param="N".
  focus(event) {
    const marker = this.markers[event.params.index]
    if (!marker) return
    this.map.flyTo(marker.getLatLng(), Math.max(this.map.getZoom(), 16), { duration: 0.6 })
    marker.openTooltip()
    if (window.innerWidth < 1024) this.frameTarget.scrollIntoView({ behavior: "smooth", block: "center" })
  }

  toggleFullscreen() {
    const full = this.frameTarget.classList.toggle("places-map-full")
    document.body.style.overflow = full ? "hidden" : ""
    if (this.hasFullscreenLabelTarget) this.fullscreenLabelTarget.textContent = full ? this.fullscreenLabelTarget.dataset.close : this.fullscreenLabelTarget.dataset.open
    setTimeout(() => { this.map.invalidateSize(); this.fit() }, 50)
    if (full) this.enableWheel()
  }

  enableWheel() {
    this.map.scrollWheelZoom.enable()
    if (this.hasHintTarget) this.hintTarget.remove()
  }

  escape(text) {
    const div = document.createElement("div")
    div.textContent = text || ""
    return div.innerHTML
  }
}
