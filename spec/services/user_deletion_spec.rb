require "rails_helper"

RSpec.describe UserDeletion do
  let(:user) { create(:user) }
  let(:account) { create(:account, owner: user) }

  before { create(:membership, user: user, account: account, role: "owner", status: "active") }

  # Uma conta com um pouco de tudo, para provar que a exclusão em cascata não esbarra em chave estrangeira.
  def populate(account, user)
    create(:app_usage, account: account, date: Date.current - 1, seconds: 600)
    AppUsageSlot.create!(account: account, date: Date.current - 1, slot: 10, bundle_id: "X", seconds: 60)
    create(:measurement, account: account, key: "steps", value: 5000, category: "health", measured_on: Date.current - 1)
    Workout.create!(account: account, uuid: "w", activity: "running", started_at: 1.day.ago, date: Date.current - 1, duration_seconds: 60)
    account.weight_entries.create!(date: Date.current, weight_kg: 80)
    category = create(:habit_category, account: account)
    habit = create(:habit, account: account, habit_category: category)
    habit.habit_checks.create!(date: Date.current)
    board = TaskBoard.create_with_columns!(account: account, name: "Pessoal")
    task = board.tasks.create!(account: account, task_column: board.columns.first, title: "Tarefa", creator: user)
    task.comments.create!(body: "comentário", user: user)
    TaskMover.new(task).call(column: board.columns.last, user: user)
    IngestionLog.create!(account: account, endpoint: "usage", status: 200)
    client = OauthClient.create!(client_id: "c-#{account.id}", redirect_uris: ["https://claude.ai/cb"])
    account.oauth_grants.create!(user: user, oauth_client: client, redirect_uri: "https://claude.ai/cb")
    account.enable_mcp!
    task
  end

  it "deletes the user and everything in an account that is only theirs" do
    populate(account, user)
    other_account = create(:account)
    create(:app_usage, account: other_account, date: Date.current - 1, seconds: 60)

    result = described_class.new(user).call

    expect(result).to be_ok
    expect(result.deleted_accounts).to eq(1)
    expect(User.exists?(user.id)).to be(false)
    expect(Account.exists?(account.id)).to be(false)
    [AppUsage, AppUsageSlot, Measurement, Workout, WeightEntry, Habit, HabitCheck, Task, TaskComment, TaskEvent,
     TaskBoard, TaskColumn, IngestionLog, OauthGrant, Membership].each do |model|
      scope = model.column_names.include?("account_id") ? model.where(account_id: account.id) : model.all
      expect(scope.count).to eq(0), "#{model} ainda tem registros"
    end
    expect(other_account.app_usages.count).to eq(1) # dados de outras contas intactos
  end

  it "keeps a shared account alive: hands ownership over and detaches authorship" do
    partner = create(:user)
    create(:membership, user: partner, account: account, role: "member", status: "active")
    task = populate(account, user)

    result = described_class.new(user).call

    expect(result).to have_attributes(ok: true, deleted_accounts: 0, left_accounts: 1)
    expect(User.exists?(user.id)).to be(false)
    expect(account.reload.owner).to eq(partner)
    expect(partner.membership_for(account)).to have_attributes(role: "owner")
    expect(task.reload).to have_attributes(creator_id: nil)
    expect(task.comments.first.user_id).to be_nil
    expect(task.events.pluck(:user_id).uniq).to eq([nil])
    expect(account.oauth_grants.count).to eq(0) # autorizações dele saem junto
    expect(account.measurements.count).to eq(1) # os dados da conta ficam para quem continua
  end

  it "deletes the account when the only other members are still pending" do
    create(:membership, :pending, user: create(:user), account: account, role: "member")
    expect(described_class.new(user).call.deleted_accounts).to eq(1)
    expect(Account.exists?(account.id)).to be(false)
  end

  it "refuses to delete a platform administrator and changes nothing" do
    user.add_role(:admin)
    result = described_class.new(user).call
    expect(result).to have_attributes(ok: false, error: :platform_admin)
    expect(User.exists?(user.id)).to be(true)
    expect(Account.exists?(account.id)).to be(true)
  end
end
