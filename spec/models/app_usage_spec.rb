# == Schema Information
#
# Table name: app_usages
#
#  id         :bigint           not null, primary key
#  date       :date             not null
#  device     :string           default("iphone"), not null
#  name       :string
#  seconds    :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  bundle_id  :string           not null
#
# Indexes
#
#  idx_app_usages_unique           (account_id,device,date,bundle_id) UNIQUE
#  index_app_usages_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
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
