class WhitelabelsController < ApplicationController
   def new
    @whitelabel = Whitelabel.new
   end
   

   def create
    @whitelabel = Whitelabel.new(params[:whitelabel])
    @whitelabel.whitelabel_req = "Nom de l'organisation: " + @whitelabel.name + '<br />' + "Représentant légal: " + @whitelabel.rep_name + '<br />' + "Adresse souhaitée du site: " + @whitelabel.domain_name + '<br />' + "Contact email de l'organisation: " + @whitelabel.contact_email + '<br />' + "Monnaie des collectes: " + @whitelabel.currency + '<br />' + "URL Facebook de l'organisation: " + @whitelabel.facebook_url + '<br />' + "URL Twitter de l'organisation: " + @whitelabel.twitter_url + '<br />' + "Message supplémentaire: " + @whitelabel.message  
    if @whitelabel.deliver 
       render :thank_you
    else
       render :new
    end
   end

end
