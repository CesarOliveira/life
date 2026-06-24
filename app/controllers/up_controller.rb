class UpController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    head :ok
  end

  def databases
    RedisConn.current.ping
    ActiveRecord::Base.connection.execute("SELECT 1")

    head :ok
  end
end
