class ScreenTimeController < ApplicationController
  def index
    current_account.regenerate_api_token if current_account.api_token.blank?
    @token = current_account.api_token

    @today = Date.current
    @range = (@today - 6.days)..@today
    usages = current_account.app_usages.in_range(@range)

    @total_week = usages.sum(:seconds)
    @total_today = usages.where(date: @today).sum(:seconds)

    names = usages.where.not(name: nil).group(:bundle_id).maximum(:name)
    @apps = usages.group(:bundle_id).sum(:seconds)
                  .map { |bundle_id, seconds| { bundle_id: bundle_id, name: names[bundle_id].presence || bundle_id, seconds: seconds } }
                  .sort_by { |a| -a[:seconds] }
    @max_app = @apps.map { |a| a[:seconds] }.max || 0
  end

  def regenerate
    current_account.regenerate_api_token
    redirect_to screen_time_path, notice: t("flash.screen_time.token_regenerated")
  end
end
