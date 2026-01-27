module UsersHelper
  # Champ requis pour le profil utilisateur (anciennement required_by_mangopay)
  def required_field(for_element, text_content)
    label_tag for_element do
      concat content_tag(:abbr, '**', class: 'required_field', title: I18n.t('users.edit.required_field', default: 'Champ requis').capitalize)
      concat ' '
      concat text_content
    end
  end
  
  # Alias pour compatibilité avec les vues existantes
  alias_method :required_by_mangopay, :required_field

  def required_for_projects(required, for_element, text_content)
    label_tag for_element do
      if required
        concat content_tag(:abbr, '**', class: 'required_for_projects', title: I18n.t('users.edit.projects.required').capitalize)
        concat ' '
      end
      concat text_content
    end
  end

  def kycs_available_type_to_display(user)
    res = {}
    user.document_types.each do |t|
      translation = t("users.settings.kyc.type.#{t.downcase}")
      res[t] = translation
    end
    res.invert
  end

  def kyc_translated_status(status)
    t("users.settings.kyc.type.#{status.downcase}")
  end
end
