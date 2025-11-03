class AddDonationCanIssueTaxReceiptToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :donation_can_issue_tax_receipt, :boolean, default: false
  end
end
