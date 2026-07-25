# Vérification de la configuration AWS au démarrage de l'application
# Évite les problèmes d'upload d'images en production

if (Rails.env.production? || Rails.env.staging?) && ENV['AWS_ACCESS_KEY'].present?
  
  required_aws_vars = {
    'AWS_ACCESS_KEY'     => ENV['AWS_ACCESS_KEY'],
    'AWS_SECRET_KEY'     => ENV['AWS_SECRET_KEY'],
    'AWS_BUCKET'         => ENV['AWS_BUCKET'],
    'AWS_REGION'         => ENV['AWS_REGION']
  }
  
  missing_vars = required_aws_vars.select { |k, v| v.blank? }.keys
  
  if missing_vars.any?
    error_message = <<~ERROR
      
      ❌ ERREUR CONFIGURATION AWS
      ================================================================================
      Les variables d'environnement suivantes sont OBLIGATOIRES mais ABSENTES :
      #{missing_vars.map { |v| "  - #{v}" }.join("\n")}
      
      L'upload d'images vers S3 ne fonctionnera PAS sans ces variables.
      
      Veuillez configurer ces variables dans Heroku:
        heroku config:set #{missing_vars.map { |v| "#{v}=..." }.join(' ')}
      
      Région recommandée : AWS_REGION=us-east-1
      ================================================================================
      
    ERROR
    
    Rails.logger.error(error_message)
    
    # En production, on alerte mais on ne crash pas l'app
    # Les admins verront l'erreur dans les logs
    warn error_message
    
    # Envoyer une notification Rollbar si disponible
    if defined?(Rollbar)
      Rollbar.error("AWS configuration incomplete", {
        missing_vars: missing_vars,
        environment: Rails.env
      })
    end
  else
    Rails.logger.info("✅ Configuration AWS complète (région: #{ENV['AWS_REGION']})")
  end
  
end
