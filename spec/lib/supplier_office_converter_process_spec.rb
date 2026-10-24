# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'
require Rails.root.join('lib/supplier_office_converter_process')

RSpec.describe SupplierOfficeConverterProcess do
  around do |example|
    Dir.mktmpdir('office-conversion-test-') do |directory|
      @directory = directory
      @input = File.join(directory, 'document.docx')
      File.write(@input, 'test input')
      example.run
    end
  end

  it 'rejects a missing source file without launching a subprocess' do
    expect(Process).not_to receive(:spawn)
    expect(described_class.call(directory: @directory, input: File.join(@directory, 'absent.docx'))).to be(false)
  end

  it 'rejects a source file outside the isolated conversion directory' do
    nested = File.join(@directory, 'nested')
    Dir.mkdir(nested)
    outside = File.join(nested, 'document.docx')
    File.write(outside, 'test')
    expect(Process).not_to receive(:spawn)
    expect(described_class.call(directory: @directory, input: outside)).to be(false)
  end

  it 'accepts successful converter exit status' do
    allow(Process).to receive(:spawn).and_return(411)
    allow(Process).to receive(:waitpid2).with(411).and_return([411, double(success?: true)])
    expect(described_class.call(directory: @directory, input: @input)).to be(true)
  end

  it 'rejects nonzero converter exit status' do
    allow(Process).to receive(:spawn).and_return(412)
    allow(Process).to receive(:waitpid2).with(412).and_return([412, double(success?: false)])
    expect(described_class.call(directory: @directory, input: @input)).to be(false)
  end

  it 'terminates the process group when conversion exceeds the limit' do
    allow(Process).to receive(:spawn).and_return(413)
    allow(Timeout).to receive(:timeout).and_raise(Timeout::Error)
    expect(Process).to receive(:kill).with('KILL', -413)
    expect(Process).to receive(:waitpid).with(413)
    expect(described_class.call(directory: @directory, input: @input)).to be(false)
  end

  it 'fails closed when the converter subprocess has already disappeared' do
    allow(Process).to receive(:spawn).and_return(414)
    allow(Process).to receive(:waitpid2).with(414).and_raise(Errno::ECHILD)
    expect(described_class.call(directory: @directory, input: @input)).to be(false)
  end
end
