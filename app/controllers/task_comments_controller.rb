class TaskCommentsController < ApplicationController
  before_action :set_task

  def create
    comment = @task.comments.new(body: params.dig(:task_comment, :body), user: current_user)
    if comment.save
      redirect_to task_path(@task), notice: t("flash.tasks.comment_added")
    else
      redirect_to task_path(@task), alert: comment.errors.full_messages.to_sentence
    end
  end

  def destroy
    @task.comments.find(params[:id]).destroy
    redirect_to task_path(@task), notice: t("flash.tasks.comment_removed")
  end

  private

  def set_task
    @task = current_account.tasks.find(params[:task_id])
  end
end
