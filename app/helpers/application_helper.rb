module ApplicationHelper
  # Link de navegação com destaque para a página atual.
  def nav_link(text, path)
    base = "shrink-0 whitespace-nowrap px-3 py-1.5 rounded-lg text-sm font-medium transition-colors"
    state = current_page?(path) ? "bg-slate-100 text-slate-900" : "text-slate-500 hover:text-slate-900 hover:bg-slate-100"
    link_to text, path, class: "#{base} #{state}"
  end

  # URL da página atual trocando o idioma (preserva o path e os params).
  def locale_switch_path(locale)
    query = request.query_parameters.merge(locale: locale)
    "#{request.path}?#{query.to_query}"
  end

  # Abreviação do idioma para o seletor (ex.: "PT", "EN").
  def locale_label(locale)
    locale.to_s.split("-").first.upcase
  end

  # Duração legível a partir de segundos: "2h 7m", "43m", "0m".
  def humanize_duration(seconds)
    seconds = seconds.to_i
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    hours.positive? ? "#{hours}h #{minutes}m" : "#{minutes}m"
  end

  # Duração em horas/min a partir de minutos: "6h 32m", "45m".
  def humanize_minutes(minutes)
    humanize_duration(minutes.to_i * 60)
  end

  # Token mascarado: mostra início e fim, esconde o miolo. O valor inteiro é
  # buscado só ao copiar (ver clipboard_controller + screen_time#token).
  def masked_token(token)
    str = token.to_s
    return str if str.length <= 10

    "#{str.first(4)}#{'•' * 10}#{str.last(4)}"
  end

  # Ícone SVG inline por métrica de saúde (coração p/ FC, passos, sono...).
  # Segue a convenção do app: SVG inline, dimensionado por Tailwind.
  def metric_icon(key, css: "h-5 w-5")
    paths = METRIC_ICON_PATHS[key.to_s]
    return nil if paths.nil?

    content_tag(:svg, paths.html_safe, class: css, viewBox: "0 0 24 24", fill: "none",
                stroke: "currentColor", "stroke-width": "2", "stroke-linecap": "round",
                "stroke-linejoin": "round", "aria-hidden": "true")
  end

  METRIC_ICON_PATHS = {
    "resting_hr" => '<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.29 1.51 4.04 3 5.5l7 7Z"/>',
    "steps" => '<path d="M6 21c-1.5 0-2.5-1-2.5-3 0-1.2.3-2.3.3-3.5C4 12 4.5 10 6.5 10S9 12 9 14.5c0 1.3-.3 2.4-.3 3.5C8.7 20 7.5 21 6 21Z"/><path d="M6.5 10c0-2 .2-3.4-.3-5.2C5.8 3.4 6.4 2 8 2s2.2 1.4 1.8 2.8C9.3 6.6 9.5 8 9.5 10"/><path d="M17.5 22c1.4 0 2.3-1 2.3-2.8 0-1.1-.3-2.1-.3-3.2 0-2.3-.5-4-2.3-4S15 13.7 15 16c0 1.1.3 2.1.3 3.2 0 1.8.8 2.8 2.2 2.8Z"/>',
    "sleep_minutes" => '<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>',
    "sleep_bedtime" => '<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>',
    "sleep_wake" => '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M6.3 17.7l-1.4 1.4M19.1 4.9l-1.4 1.4"/>',
    "active_energy" => '<path d="M13 2 4.5 13.5H11l-1 8.5L19.5 10H13l0-8Z"/>'
  }.freeze
end
