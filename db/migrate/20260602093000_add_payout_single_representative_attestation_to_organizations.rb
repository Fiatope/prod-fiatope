class AddPayoutSingleRepresentativeAttestationToOrganizations < ActiveRecord::Migration[6.1]
  def change
    add_column :organizations, :payout_single_representative_attested_at, :datetime unless column_exists?(:organizations, :payout_single_representative_attested_at)
  end
end
