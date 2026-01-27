# Migration consolidée pour TOUTES les colonnes Stripe
# Cette migration est idempotente - elle vérifie si les colonnes existent avant de les ajouter
class AddAllStripeColumnsConsolidated < ActiveRecord::Migration[6.1]
  def up
    # ============================================
    # TABLE: contributions
    # ============================================
    unless column_exists?(:contributions, :stripe_transferred)
      add_column :contributions, :stripe_transferred, :boolean, default: false
      add_index :contributions, :stripe_transferred
    end

    unless column_exists?(:contributions, :stripe_transfer_id)
      add_column :contributions, :stripe_transfer_id, :string
    end

    unless column_exists?(:contributions, :stripe_refunded)
      add_column :contributions, :stripe_refunded, :boolean, default: false
      add_index :contributions, :stripe_refunded
    end

    unless column_exists?(:contributions, :stripe_refund_id)
      add_column :contributions, :stripe_refund_id, :string
    end

    unless column_exists?(:contributions, :stripe_charge_id)
      add_column :contributions, :stripe_charge_id, :string
    end

    # ============================================
    # TABLE: projects
    # ============================================
    unless column_exists?(:projects, :stripe_account_id)
      add_column :projects, :stripe_account_id, :string
      add_index :projects, :stripe_account_id
    end

    unless column_exists?(:projects, :use_stripe)
      add_column :projects, :use_stripe, :boolean, default: true
    end

    unless column_exists?(:projects, :stripe_transfer_id)
      add_column :projects, :stripe_transfer_id, :string
    end

    unless column_exists?(:projects, :stripe_settled_at)
      add_column :projects, :stripe_settled_at, :datetime
      add_index :projects, :stripe_settled_at
    end

    unless column_exists?(:projects, :stripe_settlement_type)
      add_column :projects, :stripe_settlement_type, :string
    end

    # ============================================
    # TABLE: users
    # ============================================
    unless column_exists?(:users, :stripe_customer_id)
      add_column :users, :stripe_customer_id, :string
      add_index :users, :stripe_customer_id
    end

    unless column_exists?(:users, :stripe_connect_account_id)
      add_column :users, :stripe_connect_account_id, :string
      add_index :users, :stripe_connect_account_id
    end

    unless column_exists?(:users, :stripe_onboarding_complete)
      add_column :users, :stripe_onboarding_complete, :boolean, default: false
    end

    # ============================================
    # TABLE: stripe_orders (si n'existe pas)
    # ============================================
    unless table_exists?(:stripe_orders)
      create_table :stripe_orders do |t|
        t.references :user, null: false, foreign_key: true
        t.references :project, null: false, foreign_key: true
        t.references :contribution, foreign_key: true
        t.string :stripe_payment_intent_id
        t.string :stripe_checkout_session_id
        t.string :stripe_charge_id
        t.string :stripe_transfer_id
        t.integer :amount_cents, null: false
        t.string :currency, default: 'eur'
        t.integer :platform_fee_cents
        t.string :status
        t.jsonb :metadata
        t.timestamps
      end

      add_index :stripe_orders, :stripe_payment_intent_id
      add_index :stripe_orders, :stripe_checkout_session_id
      add_index :stripe_orders, :status
    end

    # ============================================
    # Synchroniser stripe_account_id des projets existants
    # ============================================
    execute <<-SQL
      UPDATE projects p
      SET stripe_account_id = u.stripe_connect_account_id
      FROM users u
      WHERE p.user_id = u.id
        AND u.stripe_connect_account_id IS NOT NULL
        AND (p.stripe_account_id IS NULL OR p.stripe_account_id = '');
    SQL

    Rails.logger.info "✅ Migration Stripe consolidée terminée avec succès"
  end

  def down
    # Ne pas supprimer les colonnes en cas de rollback - données critiques
    Rails.logger.warn "⚠️ Rollback de la migration Stripe - colonnes conservées pour sécurité"
  end
end
