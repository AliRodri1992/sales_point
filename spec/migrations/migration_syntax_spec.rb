# frozen_string_literal: true

require 'spec_helper'
require 'ripper'

RSpec.describe 'Database migration syntax' do
  it 'parses every migration before it is executed' do
    migration_paths = Dir[File.expand_path('../../db/migrate/*.rb', __dir__)].sort

    expect(migration_paths).not_to be_empty

    invalid_paths = migration_paths.reject { |path| Ripper.sexp(File.read(path)) }
    expect(invalid_paths).to be_empty
  end
end
