class Whitelabel
  extend ActiveModel::Naming  
  include ActiveModel::Conversion    
  include ActiveModel::Validations
  include ActionView::Helpers::TextHelper

  attr_accessor :name, :email, :rep_name, :addr, :telephone, :message, :whitelabel_req
   
  validates :name,
            :presence => true 

  validates :email,
            :format => { :with => /\b[A-Z0-9._%a-z\-]+@(?:[A-Z0-9a-z\-]+\.)+[A-Za-z]{2,4}\z/ }

  validates :rep_name,
            :presence => true         

  validates :addr,
            :presence => true
      
  validates :telephone,
            :presence => true

  validates :message,
            :length => { :minimum => 10, :maximum => 1000 }

  

  def initialize(attributes = {})    
    attributes.each do |name, value|      
     send("#{name}=", value)    
    end  
  end    

  def deliver    
    return false unless valid?
    Pony.mail({
      :from => %("#{name}" <#{email}>),
      :reply_to => email,
      :subject => "Demande de WhiteLabel Fiatope",
      :body => whitelabel_req,
      :html_body => simple_format(whitelabel_req)
    })

  end        

  def persisted?    
   false  
  end
end 

