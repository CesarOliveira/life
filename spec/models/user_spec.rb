# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  name                   :string           default(""), not null
#  provider               :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  uid                    :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_provider_and_uid      (provider,uid) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
require "rails_helper"

RSpec.describe User, type: :model do
  describe "roles" do
    it "grants and checks a role" do
      user = create(:user)
      expect(user.role?(:admin)).to be false
      user.add_role(:admin)
      expect(user.role?(:admin)).to be true
    end

    it "supports multiple roles per user" do
      user = create(:user)
      user.add_role(:admin)
      user.add_role(:member)
      expect(user.roles.pluck(:name)).to match_array(%w[admin member])
    end

    it "does not duplicate a role" do
      user = create(:user)
      2.times { user.add_role(:admin) }
      expect(user.roles.where(name: "admin").count).to eq(1)
    end

    it "removes a role" do
      user = create(:user, :admin)
      user.remove_role(:admin)
      expect(user.reload.role?(:admin)).to be false
    end
  end

  describe "#platform_admin?" do
    it "is true only when the user has the admin role" do
      user = create(:user)
      expect(user.platform_admin?).to be false
      user.add_role(:admin)
      expect(user.platform_admin?).to be true
    end
  end

  describe "#super_admin?" do
    it "is true only when the user has the super_admin role" do
      user = create(:user)
      expect(user.super_admin?).to be false
      user.add_role(:super_admin)
      expect(user.super_admin?).to be true
    end
  end

  describe "roles cumulativas" do
    it "permite admin e super_admin ao mesmo tempo (acesso a ambos)" do
      user = create(:user)
      user.add_role(:admin)
      user.add_role(:super_admin)
      expect(user.platform_admin?).to be true
      expect(user.super_admin?).to be true
    end
  end
end
