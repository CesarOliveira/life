import { Controller } from "@hotwired/stimulus"

// Importa a Linha do Tempo do Google lendo o arquivo NO NAVEGADOR: só as visitas
// (início, fim, coordenada, dica) vão para o Life, nunca o arquivo inteiro.
// Formatos aceitos:
//  - Android (2024+): Timeline.json com "semanticSegments"
//  - iPhone: location-history.json (lista com "visit.topCandidate.placeLocation": "geo:lat,lng")
//  - Takeout antigo: "Semantic Location History" ({"timelineObjects": [{"placeVisit": …}]})
export default class extends Controller {
  static targets = ["input", "status", "button"]
  static values = { url: String }

  async import() {
    const files = Array.from(this.inputTarget.files || [])
    if (files.length === 0) return this.say("Escolha o arquivo exportado do Google Maps.")
    this.buttonTarget.disabled = true
    try {
      let visits = []
      for (const file of files) {
        this.say(`Lendo ${file.name}…`)
        const data = JSON.parse(await file.text())
        visits = visits.concat(this.extract(data))
      }
      if (visits.length === 0) return this.say("Nenhuma visita encontrada nesse arquivo. Confira se é a exportação da Linha do Tempo.")
      let created = 0, updated = 0
      for (let i = 0; i < visits.length; i += 500) {
        this.say(`Enviando ${Math.min(i + 500, visits.length)} de ${visits.length} visitas…`)
        const r = await this.send(visits.slice(i, i + 500))
        created += r.created || 0
        updated += r.updated || 0
      }
      this.say(`Pronto: ${created} visitas novas e ${updated} atualizadas. Recarregando…`)
      setTimeout(() => window.location.reload(), 1200)
    } catch (e) {
      this.say(`Não deu para importar: ${e.message}`)
    } finally {
      this.buttonTarget.disabled = false
    }
  }

  extract(data) {
    const out = []
    const push = (start, end, lat, lng, hint, placeId, address) => {
      if (!start || lat == null || lng == null || isNaN(lat) || isNaN(lng)) return
      const t = Date.parse(start)
      if (isNaN(t)) return
      out.push({
        external_id: `google:${placeId || `${lat.toFixed(4)},${lng.toFixed(4)}`}:${Math.round(t / 1000)}`,
        arrived_at: start, departed_at: end || null, latitude: lat, longitude: lng,
        hint: this.hint(hint), address: address || null
      })
    }

    // Android: { semanticSegments: [...] }
    const segments = Array.isArray(data) ? data : (data.semanticSegments || null)
    if (segments) {
      for (const s of segments) {
        const v = s.visit
        if (!v || !v.topCandidate) continue
        if (v.hierarchyLevel != null && String(v.hierarchyLevel) !== "0") continue
        const c = v.topCandidate
        const [lat, lng] = this.latLng(c.placeLocation)
        push(s.startTime, s.endTime, lat, lng, c.semanticType, c.placeId || c.placeID)
      }
    }

    // Takeout antigo: { timelineObjects: [{ placeVisit }] }
    for (const o of data.timelineObjects || []) {
      const pv = o.placeVisit
      if (!pv || !pv.location || !pv.duration) continue
      const loc = pv.location
      const address = [loc.name, loc.address].filter(Boolean).join(" · ")
      push(pv.duration.startTimestamp || pv.duration.startTimestampMs && new Date(+pv.duration.startTimestampMs).toISOString(),
           pv.duration.endTimestamp || pv.duration.endTimestampMs && new Date(+pv.duration.endTimestampMs).toISOString(),
           loc.latitudeE7 / 1e7, loc.longitudeE7 / 1e7, loc.semanticType, loc.placeId, address)
    }
    return out
  }

  // "-21.4042394°, -48.5108729°" | "geo:-21.404239,-48.510873" | { latLng: "…" }
  latLng(loc) {
    const text = typeof loc === "string" ? loc : (loc && (loc.latLng || loc.point)) || ""
    const m = String(text).match(/(-?\d+(?:\.\d+)?)°?\s*,\s*(-?\d+(?:\.\d+)?)/)
    return m ? [parseFloat(m[1]), parseFloat(m[2])] : [null, null]
  }

  hint(type) {
    if (!type) return null
    const t = String(type).toUpperCase().replace(/^TYPE_/, "")
    return ["HOME", "WORK", "INFERRED_HOME", "INFERRED_WORK"].includes(t) ? t : null
  }

  async send(visits) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const r = await fetch(this.urlValue, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": token, Accept: "application/json" },
      body: JSON.stringify({ visits })
    })
    if (!r.ok) throw new Error(`o Life respondeu ${r.status}`)
    return r.json()
  }

  say(text) {
    this.statusTarget.textContent = text
  }
}
