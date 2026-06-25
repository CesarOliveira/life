module ApplicationHelper
  # Link de navegação com destaque para a página atual.
  def nav_link(text, path)
    base = "px-3 py-1.5 rounded-lg text-sm font-medium transition-colors"
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
end
