# frozen_string_literal: true

require 'timeout'

# Single audited process boundary for Office conversions. The executable and
# flags are fixed and no shell is used. Files are created inside a private
# temporary directory by Suppliers::OfficeDocumentPdf.
class SupplierOfficeConverterProcess
  MAX_SECONDS = 25
  EXECUTABLE = '/usr/bin/libreoffice'

  def self.call(directory:, input:)
    return false unless File.file?(input)
    return false unless File.dirname(File.realpath(input)) == File.realpath(directory)

    new(directory, input).call
  end

  def initialize(directory, input)
    @directory = directory
    @input = input
  end

  def call
    pid = Process.spawn(*command, chdir: @directory, pgroup: true,
                                  out: File::NULL, err: File::NULL)
    begin
      _pid, status = Timeout.timeout(MAX_SECONDS) { Process.waitpid2(pid) }
      status.success?
    rescue Timeout::Error
      Process.kill('KILL', -pid)
      Process.waitpid(pid)
      false
    rescue Errno::ESRCH, Errno::ECHILD
      false
    end
  end

  private

  def command
    profile = "file://#{File.join(@directory, 'profile')}"
    [EXECUTABLE, "-env:UserInstallation=#{profile}", '--headless',
     '--nologo', '--nodefault', '--norestore',
     '--convert-to', 'pdf', '--outdir', @directory, @input]
  end
end
