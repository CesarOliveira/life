module ScreenTimeHelper
  # Rótulo do período selecionado (ex.: "Ontem, 5 de julho", "Últimos 30 dias",
  # "3 meses", "01/06/2026 – 06/07/2026").
  def screen_time_period_label(range_key:, from:, to:, months:)
    case range_key
    when "today" then "#{t('screen_time.today')}, #{l(to, format: :long)}"
    when "yesterday" then "#{t('screen_time.yesterday')}, #{l(to, format: :long)}"
    when "custom" then "#{l(from, format: :numeric)} – #{l(to, format: :numeric)}"
    when "months" then months == 12 ? t("screen_time.one_year") : t("screen_time.n_months", count: months)
    else t("screen_time.period_last_days", days: (to - from).to_i + 1)
    end
  end
end
