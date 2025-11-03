class Category < ActiveRecord::Base
  self.primary_key = "id"
  
  has_many :projects
  validates_presence_of :name_pt
  validates_uniqueness_of :name_pt

  def self.with_projects
    where("exists(select true from projects p where p.category_id = categories.id and p.state not in('draft', 'rejected'))")
  end

  def self.array
    [['Sélectionner une option', '']].concat order('name_'+ I18n.locale.to_s + ' ASC').collect { |c| [c.send('name_' + I18n.locale.to_s), c.id] }
  end

  # TODOOO FIX ERROR WHEN NO TRAD
  def to_s
    self.send('name_' + I18n.locale.to_s)
  end
end
