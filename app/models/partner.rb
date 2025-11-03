# coding: utf-8
class Partner < ActiveRecord::Base

  extend  CatarseAutoHtml

  mount_uploader :uploaded_image, ProjectUploader, mount_on: :uploaded_image
  mount_uploader :hero_image, HeroImageUploader, mount_on: :hero_image

  has_many :projects, dependent: :destroy
  has_many :users, dependent: :destroy
  belongs_to :category

  validates :name, presence: true
  validates :headline, presence: true
  validates :permalink, presence: true

  catarse_auto_html_for field: :about, video_width: 720, video_height: 405

  def self.array
    self.all.collect { |c| [c.name, c.id] }
  end

  before_save do
    self.permalink = self.permalink.try(:downcase)
  end
end
