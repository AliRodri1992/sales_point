module DashboardHelper
  def javascript_dashboard_translations
    {
      customize_dashboard: t('admin.dashboard.page_header.customize'),
      save_changes: t('admin.dashboard.page_header.save_changes'),
      saved_title: t('admin.dashboard.saved.title'),
      saved_text: t('admin.dashboard.saved.text'),
      save_error_title: t('admin.dashboard.save_error.title'),
      save_error_text: t('admin.dashboard.save_error.text')
    }.to_json
  end
end
