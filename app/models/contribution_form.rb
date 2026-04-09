class ContributionForm < Contribution
  validates_numericality_of :value, greater_than_or_equal_to: 0.01
end
