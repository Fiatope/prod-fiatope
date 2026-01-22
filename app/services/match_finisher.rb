class MatchFinisher
  def complete!
    matches.each do |match|
      # MangoPay désactivé - utilisation de Stripe ou remboursement manuel
      # Tenter le remboursement via Stripe si applicable
      if match.respond_to?(:process_refund)
        match.process_refund
      end
      
      match.complete!
      match.notify_observers :completed
    end
  end

  def matches
    projects_waiting_contributions =
      Contribution.with_state(:waiting_confirmation).
        group(:project_id).pluck(:project_id)
    Match.with_state(:confirmed).
      uncompleted.
      where('finishes_at < ?', Time.now.utc).
      where.not(project_id: projects_waiting_contributions)
  end

  def self.remaining_amount_of(match)
    match.value -
      match.matched_contributions.with_state(:confirmed).sum(:value)
  end
end
