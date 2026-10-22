# frozen_string_literal: true

require 'tmpdir'
require 'timeout'

module Suppliers
  # Converts supported Office formats to a PDF using a locally installed
  # LibreOffice binary. Each conversion has its own isolated user profile,
  # bounded input/output sizes and an operating-system process timeout.
  class OfficeDocumentPdf
    CONTENT_TYPES = %w[
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
      application/msword application/vnd.ms-excel
    ].freeze
    EXTENSIONS = %w[docx xlsx doc xls].freeze
    OUTPUT_LIMIT = 20.megabytes

    def self.binary
      ENV.fetch('LIBREOFFICE_BIN', '/usr/bin/libreoffice')
    end

    def self.available?
      File.executable?(binary)
    end

    def initialize(blob)
      @blob = blob
    end

    def call
      return unless self.class.available? && supported?
      return if @blob.byte_size > 10.megabytes

      Dir.mktmpdir('delta-office-preview-') { |directory| convert(directory) }
    rescue IOError, SystemCallError, Timeout::Error
      nil
    end

    private

    def supported?
      CONTENT_TYPES.include?(@blob.content_type) &&
        EXTENSIONS.include?(@blob.filename.extension.downcase)
    end

    def convert(directory)
      filename = "document.#{@blob.filename.extension.downcase}"
      input = File.join(directory, filename)
      output = File.join(directory, 'document.pdf')
      File.binwrite(input, @blob.download)
      return unless execute_conversion(directory, input)
      return unless File.file?(output) && File.size(output).between?(1, OUTPUT_LIMIT)

      pdf = File.binread(output)
      pdf if pdf.start_with?('%PDF-')
    end

    def execute_conversion(directory, input)
      profile = "file://#{File.join(directory, 'profile')}"
      args = [self.class.binary, "-env:UserInstallation=#{profile}", '--headless',
              '--nologo', '--nodefault', '--norestore', '--convert-to',
              'pdf', '--outdir', directory, input]
      pid = Process.spawn(*args, chdir: directory, pgroup: true,
                                 out: File::NULL, err: File::NULL)
      begin
        _pid, status = Timeout.timeout(25) { Process.waitpid2(pid) }
        status.success?
      rescue Timeout::Error
        Process.kill('KILL', -pid)
        Process.waitpid(pid)
        false
      rescue Errno::ESRCH, Errno::ECHILD
        false
      end
    end
  end
end
