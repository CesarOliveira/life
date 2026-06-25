require "rails_helper"

RSpec.describe AppUsage, type: :model do
  it { is_expected.to belong_to(:account) }

  it "requires date, bundle_id and seconds" do
    expect(build(:app_usage, date: nil)).not_to be_valid
    expect(build(:app_usage, bundle_id: nil)).not_to be_valid
    expect(build(:app_usage, seconds: nil)).not_to be_valid
  end

  it "rejects negative seconds" do
    expect(build(:app_usage, seconds: -1)).not_to be_valid
  end

  it "is unique per account + device + date + bundle_id" do
    usage = create(:app_usage)
    dup = build(:app_usage, account: usage.account, device: usage.device, date: usage.date, bundle_id: usage.bundle_id)
    expect(dup).not_to be_valid
  end
end
