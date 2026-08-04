class FixProjectTotalsContributorsCount < ActiveRecord::Migration[6.1]
  def up
    # Fiatope: Add total_contributors column to existing table
    add_column :project_totals, :total_contributors, :integer
    
    # Populate with DISTINCT user count
    execute <<-SQL
      UPDATE project_totals pt
      SET total_contributors = (
        SELECT count(DISTINCT c.user_id)
        FROM contributions c
        WHERE c.project_id = pt.project_id
          AND c.state IN ('confirmed', 'refunded', 'requested_refund')
      );
    SQL
  end

  def down
    remove_column :project_totals, :total_contributors
  end
end
