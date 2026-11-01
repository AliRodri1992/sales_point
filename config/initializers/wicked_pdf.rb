# frozen_string_literal: true

# The PDF renderer is installed in both Docker images.
# Override the executable path when running outside Docker.
WickedPdf.configure do |config|
  config.exe_path = ENV.fetch('WKHTMLTOPDF_PATH', '/usr/bin/wkhtmltopdf')
end
