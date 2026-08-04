class FixProjectTotalsContributorsCount < ActiveRecord::Migration[6.1]
  def up
    # Fiatope uses a materialized table, not a view
    execute <<-SQL
      DROP TABLE IF EXISTS project_totals CASCADE;
      
      CREATE TABLE project_totals AS
        SELECT contributions.project_id,
               sum(contributions.value) AS pledged,
               ((sum(contributions.value) / projects.goal) * (100)::numeric) AS progress,
               sum(contributions_fees.payment_service_fee) AS total_payment_service_fee,
               count(*) AS total_contributions,
               count(DISTINCT contributions.user_id) AS total_contributors,
               (sum(contributions.value) * (SELECT value::numeric FROM configurations WHERE name = 'platform_fee')) AS platform_fee,
               (sum(contributions_fees.net_payment) - (sum(contributions.value) * (SELECT value::numeric FROM configurations WHERE name = 'platform_fee'))) AS net_amount
        FROM contributions
        JOIN projects ON contributions.project_id = projects.id
        JOIN contributions_fees ON contributions_fees.id = contributions.id
        WHERE contributions.state IN ('confirmed', 'refunded', 'requested_refund')
        GROUP BY contributions.project_id, projects.goal;
      
      CREATE INDEX index_project_totals_on_project_id ON project_totals(project_id);
    SQL
  end

  def down
    execute <<-SQL
      DROP TABLE IF EXISTS project_totals CASCADE;
      
      CREATE TABLE project_totals AS
        SELECT contributions.project_id,
               sum(contributions.value) AS pledged,
               ((sum(contributions.value) / projects.goal) * (100)::numeric) AS progress,
               sum(contributions_fees.payment_service_fee) AS total_payment_service_fee,
               count(*) AS total_contributions,
               (sum(contributions.value) * (SELECT value::numeric FROM configurations WHERE name = 'platform_fee')) AS platform_fee,
               (sum(contributions_fees.net_payment) - (sum(contributions.value) * (SELECT value::numeric FROM configurations WHERE name = 'platform_fee'))) AS net_amount
        FROM contributions
        JOIN projects ON contributions.project_id = projects.id
        JOIN contributions_fees ON contributions_fees.id = contributions.id
        WHERE contributions.state IN ('confirmed', 'refunded', 'requested_refund')
        GROUP BY contributions.project_id, projects.goal;
      
      CREATE INDEX index_project_totals_on_project_id ON project_totals(project_id);
    SQL
  end
end
