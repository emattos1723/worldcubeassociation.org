module ApplicationHelper
  def full_title(page_title='')
    base_title = WcaOnRails::Application.config.site_name
    if page_title.empty?
      base_title
    else
      page_title + " | " + base_title
    end
  end

  def bootstrap_class_for(flash_type)
    {
      success: "alert-success",
      danger: "alert-danger",
      warning: "alert-warning",
      info: "alert-info",

      # For devise
      notice: "alert-success",
      alert: "alert-danger",

      recaptcha_error: "alert-danger"
    }[flash_type.to_sym] || flash_type.to_s
  end

  def md(content)
    Redcarpet::Markdown.new(Redcarpet::Render::HTML.new).render(content).html_safe
  end

  def filename_to_url(filename)
    "/" + Pathname.new(File.absolute_path(filename)).relative_path_from(Rails.public_path).to_path
  end

  def anchorable(pretty_text)
    id = pretty_text.parameterize
    "<span id='#{id}' class='anchorable'>#{pretty_text} <a href='##{id}'><span class='glyphicon glyphicon-link'></span></a></span>".html_safe
  end

  WCA_EXCERPT_RADIUS = 50

  def wca_excerpt(html, phrase)
    text = ActiveSupport::Inflector.transliterate(strip_tags(html)) # TODO https://github.com/cubing/worldcubeassociation.org/issues/238
    excerpted = excerpt(text, phrase, radius: WCA_EXCERPT_RADIUS)
    # If nothing matches the given phrase, just return the beginning.
    if excerpted.blank?
      excerpted = truncate(text, length: WCA_EXCERPT_RADIUS)
    end
    wca_highlight(excerpted, phrase)
  end

  def wca_highlight(html, phrases)
    text = ActiveSupport::Inflector.transliterate(strip_tags(html)) # TODO https://github.com/cubing/worldcubeassociation.org/issues/238
    highlight(text, phrases, highlighter: '<strong>\1</strong>')
  end

  def wca_omni_search
    text_field_tag nil, @omni_query, placeholder: "Search site", class: "form-control wca-autocomplete wca-autocomplete-omni wca-autocomplete-search wca-autocomplete-only_one wca-autocomplete-users_search wca-autocomplete-persons_table"
  end

  def wca_local_time(time)
    local_time(time, "%B %e, %Y %l:%M%P %Z")
  end

  def notifications_for_user(user)
    notifications = []
    # Be careful to not show a competition twice if we're both organizing and delegating it.
    unconfirmed_competitions = (user.delegated_competitions.where(isConfirmed: false) + user.organized_competitions.where(isConfirmed: false)).uniq &:id
    unconfirmed_competitions.each do |unconfirmed_competition|
      notifications << {
        text: "#{unconfirmed_competition.name} is not confirmed",
        url: edit_competition_path(unconfirmed_competition),
      }
    end
    if user.board_member?
      # Show board members:
      #  - Confirmed, but not visible competitions: They need to approve or reject
      #                                             these competitions.
      #  - Unconfirmed, but visible competitions: These competitions should be confirmed
      #                                           so people cannot change old competitions.
      Competition.where(isConfirmed: true, showAtAll: false).each do |competition|
        notifications << {
          text: "#{competition.name} is waiting to be announced",
          url: admin_edit_competition_path(competition),
        }
      end
      Competition.where(isConfirmed: false, showAtAll: true).each do |competition|
        notifications << {
          text: "#{competition.name} is visible, but unlocked",
          url: admin_edit_competition_path(competition),
        }
      end
    end

    if user.wca_id.blank?
      if user.unconfirmed_wca_id? && user.delegate_to_handle_wca_id_claim
        # The user has already claimed a WCA ID, let them know we're on it.
        notifications << {
          text: "Waiting for #{user.delegate_to_handle_wca_id_claim.name} to assign you WCA ID #{user.unconfirmed_wca_id}",
          url: profile_claim_wca_id_path,
        }
      else
        # Show users without WCA IDs how to claim a WCA ID for their account.
        notifications << {
          text: "Connect your WCA ID to your account!",
          url: profile_claim_wca_id_path,
        }
      end
    end

    user.users_claiming_wca_id.each do |user_claiming_wca_id|
      notifications << {
        text: "#{user_claiming_wca_id.email} has claimed WCA ID #{user_claiming_wca_id.unconfirmed_wca_id}",
        url: edit_user_path(user_claiming_wca_id.id, anchor: "wca_id"),
      }
    end

    if user.cannot_register_for_competition_reasons.length > 0
      notifications << {
        text: "Your profile is incomplete. You will not be able to register for competitions until you complete it!",
        url: profile_edit_path,
      }
    end

    notifications
  end
end
