class HabitsController < ApplicationController
  before_action :set_habit, only: %i[show edit update destroy]
  before_action :load_apps, only: %i[new create edit update]

  def index
    @today = Date.current
    @habits = current_account.habits.active.ordered.includes(:habit_checks).to_a
    @stats = @habits.to_h { |h| [h, HabitStats.new(h, today: @today)] }
  end

  # Página do hábito: força, sequência e timeline (feito/perdido por dia).
  def show
    @today = Date.current
    @stats = HabitStats.new(@habit, today: @today)
    @timeline = @stats.timeline(28)
    @graph = ContributionGraph.new(current_account, habit: @habit, from: @today << 3, to: @today, today: @today)
  end

  def new
    @habit = current_account.habits.new(color: Habit::DEFAULT_COLOR, weekdays: Habit::WEEKDAYS)
  end

  def create
    @habit = current_account.habits.new(habit_params)
    if @habit.save
      backfill_auto(@habit)
      redirect_to habits_path, notice: t("habits.flash.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @habit.update(habit_params)
      backfill_auto(@habit)
      redirect_to habits_path, notice: t("habits.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @habit.destroy
    redirect_to habits_path, notice: t("habits.flash.removed")
  end

  private

  def set_habit
    @habit = current_account.habits.find(params[:id])
  end

  # Apps disponíveis para o seletor do hábito "rede social" (bundle_id -> nome).
  def load_apps
    names = current_account.app_usages.where.not(name: nil).group(:bundle_id).maximum(:name)
    @apps = current_account.app_usages.distinct.pluck(:bundle_id).sort
                           .map { |bundle_id| { bundle_id: bundle_id, name: names[bundle_id].presence || bundle_id } }
  end

  # Backfill da janela recente quando o hábito é automático (preenche o histórico
  # a partir dos dados já existentes de tela/saúde).
  def backfill_auto(habit)
    return unless habit.auto?

    today = Date.current
    HabitRuleEvaluator.new(current_account).backfill(habit, from: today - 90, to: today)
  end

  def habit_params
    permitted = params.require(:habit)
                      .permit(:name, :description, :color, :active, :position, :habit_category_id,
                              :frequency, :weekly_target, :auto, :metric_key, :comparator, :threshold_value,
                              weekdays: [], app_bundle_ids: [])
    permitted[:habit_category_id] = current_account.habit_categories.find_by(id: permitted[:habit_category_id])&.id
    permitted[:auto] = ActiveModel::Type::Boolean.new.cast(permitted[:auto]) ? true : false

    if permitted[:auto]
      # Hábito automático é avaliado todo dia: cadência diária, sem meta semanal.
      permitted[:frequency] = "weekly_days"
      permitted[:weekdays] = Habit::WEEKDAYS
      permitted[:weekly_target] = nil
      apply_auto_rule(permitted)
    else
      permitted.merge!(non_auto_cadence(permitted))
      permitted[:metric_key] = nil
      permitted[:comparator] = nil
      permitted[:threshold_value] = nil
      permitted[:app_bundle_ids] = []
    end
    permitted
  end

  # Normaliza a regra de um hábito automático: limiar de horário (HH:MM -> min)
  # e lista de apps (só para a métrica de apps).
  def apply_auto_rule(permitted)
    meta = Habit::AUTO_METRICS[permitted[:metric_key]] || {}

    if meta[:time_of_day]
      time = params.dig(:habit, :threshold_time).to_s
      permitted[:threshold_value] = time =~ /\A(\d{1,2}):(\d{2})\z/ ? (::Regexp.last_match(1).to_i * 60) + ::Regexp.last_match(2).to_i : permitted[:threshold_value]
    end

    permitted[:app_bundle_ids] =
      if meta[:apps]
        Array(permitted[:app_bundle_ids]).reject(&:blank?).uniq
      else
        []
      end
  end

  def non_auto_cadence(permitted)
    frequency = Habit::FREQUENCIES.include?(permitted[:frequency]) ? permitted[:frequency] : "weekly_days"
    if frequency == "weekly_count"
      { frequency: frequency, weekdays: Habit::WEEKDAYS }
    else
      days = Array(permitted[:weekdays]).reject(&:blank?).map(&:to_i).uniq.sort
      { frequency: frequency, weekly_target: nil, weekdays: days }
    end
  end
end
