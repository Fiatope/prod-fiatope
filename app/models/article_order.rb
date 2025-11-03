class ArticleOrder < ActiveRecord::Base
  belongs_to :contribution
  belongs_to :article
end
