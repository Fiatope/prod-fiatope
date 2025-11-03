# app/assets/javascripts/init.js.coffee

# Fonction pour initialiser l'éditeur
initializeEditor = ->
  if $('#project_about').length > 0 and typeof Neighborly.markdownSettings isnt 'undefined'
    $('#project_about').markItUp(Neighborly.markdownSettings)

# Événements à écouter pour Turbolinks, PJAX ou chargement normal
$(document).on 'ready turbolinks:load pjax:end', ->
  initializeEditor()
