require "rails_helper"

RSpec.describe DemoAccount do
  it "creates a populated demo account and recreates it without duplicating" do
    account = described_class.new(email: "demo@example.com", password: "senha-demo-123").call
    expect(account.app_usages.distinct.count(:date)).to eq(DemoAccount::DAYS)
    expect(account.app_usage_slots.count).to be > 100
    expect(account.measurements.where(key: "sleep_minutes").count).to eq(DemoAccount::DAYS)
    expect(account.workouts.count).to eq(15)
    expect(account.habits.count).to eq(5)
    expect(account.tasks.count).to eq(5)
    expect(User.find_by(email: "demo@example.com").valid_password?("senha-demo-123")).to be(true)

    counts = [account.app_usages.count, account.measurements.count, account.tasks.count]
    described_class.new(email: "demo@example.com", password: "senha-demo-123").call
    expect([account.app_usages.count, account.measurements.count, account.tasks.count]).to eq(counts)
  end

  it "refuses to overwrite a real user's account" do
    real = create(:user, email: "real@example.com", name: "Ana Souza")
    expect { described_class.new(email: "real@example.com", password: "senha-demo-123").call }.to raise_error(ArgumentError)
    expect(real.reload.valid_password?("senha-demo-123")).to be(false)
  end
end
