# frozen_string_literal: true

require 'rails_helper'
require 'yaml'

RSpec.describe 'Development Docker Compose configuration' do
  let(:config) { YAML.safe_load_file(Rails.root.join('docker-compose.dev.yml')) }
  let(:services) { config.fetch('services') }

  it 'runs Puma independently from JS and CSS asset watchers' do
    web = services.fetch('web')
    assets = services.fetch('assets')

    expect(web.fetch('command')).to include('exec bin/rails server')
    expect(web.fetch('command')).not_to include('bin/dev', 'foreman')
    expect(assets.fetch('command')).to include('Procfile.assets.dev')

    procfile = Rails.root.join('Procfile.assets.dev').read
    expect(procfile).to include('js: yarn build:js:watch', 'css: yarn build:css:watch')
    expect(procfile).not_to include('web:')
    expect(assets.fetch('volumes')).to include('.:/rails')
  end

  it 'keeps the JavaScript watcher running when Compose closes stdin' do
    package_json = JSON.parse(Rails.root.join('package.json').read)
    scripts = package_json.fetch('scripts')

    expect(scripts.fetch('build:js:watch')).to include('--watch=forever')
    expect(scripts.fetch('build:js')).not_to include('--watch')
    expect(scripts.fetch('build:css:watch')).to include('--watch')

    %w[Procfile.assets.dev Procfile.dev].each do |file|
      procfile = Rails.root.join(file).read
      expect(procfile).to include('js: yarn build:js:watch')
    end
  end

  it 'restarts development services after an unexpected process exit' do
    %w[web assets sidekiq db redis].each do |name|
      expect(services.fetch(name).fetch('restart')).to eq('unless-stopped')
    end

    %w[web assets sidekiq].each do |name|
      expect(services.fetch(name).fetch('init')).to be(true)
    end
  end

  it 'keeps the persistent Postgres and Redis data volumes configured' do
    expect(services.fetch('db').fetch('volumes')).to include('pgdata:/var/lib/postgresql/data')
    expect(services.fetch('redis').fetch('volumes')).to include('redisdata:/data')
    expect(config.fetch('volumes').keys).to include('pgdata', 'redisdata')
  end

  it 'runs pre-push browser specs in a disposable container instead of the live web server' do
    runner = Rails.root.join('bin/overcommit-rspec').read

    expect(runner).to include('run --rm -T')
    expect(runner).not_to include('exec -T', 'ps --status running --quiet web')
    expect(runner).to include('RAILS_ENV=test', 'unset DATABASE_URL')
  end

  it 'keeps the test browser available in the web image' do
    expect(services.fetch('web').fetch('build').fetch('args').fetch('INSTALL_TEST_BROWSER')).to eq('true')
    expect(services.fetch('web').fetch('environment').fetch('CHROME_BINARY')).to eq('/usr/bin/chromium')
  end
end
