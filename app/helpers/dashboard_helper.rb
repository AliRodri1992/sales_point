module DashboardHelper
  def javascript_dashboard_translations
    {
      saving: t('admin.dashboard.experience.saving'),
      handle_label: t('admin.dashboard.experience.handle_label'),
      layout_updated: t('admin.dashboard.experience.layout_updated'),
      cancelled: t('admin.dashboard.experience.cancelled'),
      desktop_only: t('admin.dashboard.experience.desktop_only'),
      customize_dashboard: t('admin.dashboard.page_header.customize'),
      save_changes: t('admin.dashboard.page_header.save_changes'),
      saved_title: t('admin.dashboard.saved.title'),
      saved_text: t('admin.dashboard.saved.text'),
      save_error_title: t('admin.dashboard.save_error.title'),
      save_error_text: t('admin.dashboard.save_error.text')
    }.to_json
  end
end
