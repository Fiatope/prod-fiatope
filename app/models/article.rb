class Article < ActiveRecord::Base
  belongs_to :reward

  mount_uploader :uploaded_image, ArticleUploader, mount_on: :uploaded_image

  has_many :article_orders
  has_many :contributions, through: :article_orders

  validates_presence_of :title, :description
end
