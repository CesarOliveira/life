# == Schema Information
#
# Table name: connectors
#
#  id             :bigint           not null, primary key
#  access_token   :text
#  kind           :string           not null
#  last_error     :string
#  last_points    :integer          default(0), not null
#  last_synced_at :datetime
#  settings       :jsonb            not null
#  status         :string           default("active"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#
# Indexes
#
#  index_connectors_on_account_id           (account_id)
#  index_connectors_on_account_id_and_kind  (account_id,kind) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
require "rails_helper"

RSpec.describe Connector do
  let(:account) { create(:account) }

  it "encrypts the access token (roundtrip works, ciphertext differs)" do
    c = described_class.create!(account: account, kind: "github", access_token: "gho_secret123")
    expect(c.reload.access_token).to eq("gho_secret123")
    raw = ActiveRecord::Base.connection.select_value("SELECT access_token FROM connectors WHERE id = #{c.id}")
    expect(raw).not_to include("gho_secret123")
  end

  it "allows one connector per kind per account" do
    described_class.create!(account: account, kind: "github")
    dup = described_class.new(account: account, kind: "github")
    expect(dup).not_to be_valid
  end

  it "tracks sync state" do
    c = described_class.create!(account: account, kind: "github")
    c.mark_synced!(42)
    expect(c.last_points).to eq(42)
    expect(c.last_error).to be_nil

    c.mark_error!("boom")
    expect(c.status).to eq("error")
    expect(c.last_error).to eq("boom")
  end
end
