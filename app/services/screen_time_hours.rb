# Tempo de tela por horário, a partir dos blocos de 15 min (AppUsageSlot):
# minutos por hora do dia, primeiro/último uso e uso logo antes de dormir
# (cruzando com a hora de dormir registrada pelo Apple Watch).
class ScreenTimeHours
  BEFORE_BED_MINUTES = 60

  def initialize(account, from:, to:, app: nil)
    @account = account
    @from = from
    @to = to
    scope = account.app_usage_slots.where(date: from..to)
    scope = scope.where("lower(coalesce(name, bundle_id)) = ?", app.downcase) if app.present?
    @slots = scope.to_a
    @by_date = @slots.group_by(&:date)
  end

  def days_with_data
    @by_date.size
  end

  # { hora (0..23) => minutos médios por dia com dado }
  def average_minutes_by_hour
    return {} if @by_date.empty?

    totals = Hash.new(0)
    @slots.each { |s| totals[s.slot / 4] += s.seconds }
    (0..23).to_h { |hour| [hour, (totals[hour] / 60.0 / @by_date.size).round(1)] }
  end

  # Por dia: total, minutos por hora, primeiro e último bloco com uso.
  def days
    @by_date.sort.map do |date, slots|
      by_hour = Hash.new(0)
      slots.each { |s| by_hour[s.slot / 4] += s.seconds }
      used = slots.map(&:slot)
      { date: date, total_minutes: (slots.sum(&:seconds) / 60.0).round,
        first_use: AppUsageSlot.label(used.min), last_use_block: AppUsageSlot.label(used.max),
        minutes_by_hour: by_hour.sort.to_h { |hour, seconds| [format("%02dh", hour), (seconds / 60.0).round] } }
    end
  end

  # Para cada noite com hora de dormir registrada: quanto de tela houve nos 60
  # minutos antes de dormir e em quais apps. A noite pertence ao dia em que a
  # pessoa acorda; a hora de dormir pode cair na véspera (>= 12h) ou no próprio dia.
  def before_bed
    bedtimes = @account.measurements.where(key: "sleep_bedtime", measured_on: @from..(@to + 1)).index_by(&:measured_on)
    sleep = @account.measurements.where(key: "sleep_minutes", measured_on: @from..(@to + 1)).index_by(&:measured_on)
    all_slots = @account.app_usage_slots.where(date: (@from - 1)..(@to + 1)).group_by(&:date)

    bedtimes.sort.filter_map do |wake_date, measurement|
      minute = measurement.value.to_i
      bed_date = minute >= 720 ? wake_date - 1 : wake_date
      window = window_slots(bed_date, minute)
      next if window.all? { |date, _| all_slots[date].nil? } # sem tempo de tela sincronizado nesses dias

      apps = Hash.new(0.0)
      window.each do |date, slot, fraction|
        (all_slots[date] || []).each { |s| apps[s.name.presence || s.bundle_id] += s.seconds * fraction if s.slot == slot }
      end
      { night_of: wake_date, bedtime: format("%02d:%02d", minute / 60, minute % 60),
        sleep_minutes: sleep[wake_date]&.value&.to_i,
        screen_minutes_in_hour_before_bed: (apps.values.sum / 60).round,
        apps: apps.sort_by { |_, seconds| -seconds }.first(5).filter_map { |name, seconds| { app: name, minutes: (seconds / 60).round } if seconds >= 30 } }
    end
  end

  private

  # Blocos que cobrem [hora de dormir - 60 min, hora de dormir), com a fração de
  # cada bloco dentro da janela: [[data, slot, fração], ...]. Cruza a meia-noite.
  def window_slots(bed_date, bed_minute)
    start = bed_minute - BEFORE_BED_MINUTES
    (start...bed_minute).group_by { |minute| minute.div(15) }.map do |slot_index, minutes|
      date = slot_index.negative? ? bed_date - 1 : bed_date
      [date, slot_index % AppUsageSlot::SLOTS_PER_DAY, minutes.size / 15.0]
    end
  end
end
