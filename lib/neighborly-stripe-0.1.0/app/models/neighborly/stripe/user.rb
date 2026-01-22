module Neighborly::Stripe::User
  extend ActiveSupport::Concern
  
  included do
    has_many :stripe_orders, class_name: 'Neighborly::Stripe::Order', foreign_key: 'user_id'
    
    # Synchroniser le compte Stripe sur tous les projets quand il change
    after_save :sync_stripe_account_to_all_projects, if: :saved_change_to_stripe_connect_account_id?
  end
  
  # Synchronise le compte Stripe connecté sur TOUS les projets du porteur
  def sync_stripe_account_to_all_projects
    return unless stripe_connect_account_id.present?
    
    projects.find_each do |project|
      project.update_columns(
        stripe_account_id: stripe_connect_account_id,
        use_stripe: true
      )
    end
    
    Rails.logger.info "Stripe: Compte #{stripe_connect_account_id} synchronisé sur #{projects.count} projets pour #{email}"
  end
  
  def stripe_customer
    return @stripe_customer if @stripe_customer
    
    if stripe_customer_id.present?
      begin
        @stripe_customer = ::Stripe::Customer.retrieve(stripe_customer_id)
      rescue ::Stripe::InvalidRequestError
        @stripe_customer = create_stripe_customer
      end
    else
      @stripe_customer = create_stripe_customer
    end
    
    @stripe_customer
  end
  
  def create_stripe_connect_account!
    return stripe_connect_account_id if stripe_connect_account_id.present?
    
    account = ::Stripe::Account.create({
      type: 'express',
      country: 'FR',
      email: self.email,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true }
      },
      business_type: profile_type == 'organization' ? 'company' : 'individual',
      metadata: {
        user_id: self.id,
        platform: 'fiatope'
      }
    })
    
    # IMPORTANT: Utiliser update() et non update_column() pour déclencher le callback
    # qui synchronise le compte Stripe sur tous les projets du porteur
    update(stripe_connect_account_id: account.id)
    
    # Double vérification: synchroniser explicitement au cas où
    sync_stripe_account_to_all_projects
    
    account.id
  end
  
  def stripe_account_onboarding_url(refresh_url:, return_url:)
    create_stripe_connect_account! if stripe_connect_account_id.blank?
    
    account_link = ::Stripe::AccountLink.create({
      account: stripe_connect_account_id,
      refresh_url: refresh_url,
      return_url: return_url,
      type: 'account_onboarding'
    })
    
    account_link.url
  end
  
  def stripe_onboarding_complete?
    return false unless stripe_connect_account_id.present?
    
    begin
      account = ::Stripe::Account.retrieve(stripe_connect_account_id)
      complete = account.charges_enabled && account.payouts_enabled
      
      if complete && !stripe_onboarding_complete
        update_column(:stripe_onboarding_complete, true)
      end
      
      complete
    rescue ::Stripe::InvalidRequestError
      false
    end
  end
  
  def stripe_dashboard_url
    return nil unless stripe_connect_account_id.present?
    
    begin
      login_link = ::Stripe::Account.create_login_link(stripe_connect_account_id)
      login_link.url
    rescue ::Stripe::InvalidRequestError
      nil
    end
  end
  
  private
  
  def create_stripe_customer
    customer = ::Stripe::Customer.create({
      email: self.email,
      name: self.name,
      metadata: {
        user_id: self.id,
        platform: 'fiatope'
      }
    })
    
    update_column(:stripe_customer_id, customer.id)
    customer
  end
end
