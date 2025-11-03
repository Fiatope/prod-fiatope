class CreateArticleOrders < ActiveRecord::Migration[6.1]
  def change
    create_table :article_orders do |t|
      t.references :contribution, foreign_key: true
      t.references :article, foreign_key: true
    end
  end
end
