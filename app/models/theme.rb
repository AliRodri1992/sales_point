# frozen_string_literal: true

# Catalog of the terminal color themes. Backed by a constant rather than a
# table because every entry must have a matching `.theme-*` rule in
# app/assets/stylesheets/components/themes.css — adding one is a code change,
# not data. Keep both lists in sync.
class Theme
  DEFAULT = 'theme-material-red'

  ALL = [
    {
      id: 'theme-material-red',
      color: '#b71c1c',
      light: '#ffebee'
    },
    {
      id: 'theme-material-navy',
      color: '#0d47a1',
      light: '#e3f2fd'
    },
    {
      id: 'theme-material-school-yellow',
      color: '#fbc02d',
      light: '#fffde7'
    },
    {
      id: 'theme-saas-blue',
      color: '#4f46e5',
      light: '#e0e7ff'
    },
    {
      id: 'theme-emerald-green',
      color: '#10b981',
      light: '#d1fae5'
    },
    {
      id: 'theme-commercial-orange',
      color: '#ea580c',
      light: '#ffedd5'
    },
    {
      id: 'theme-industrial-mono',
      color: '#18181b',
      light: '#f4f4f5'
    },
    {
      id: 'theme-tech-purple',
      color: '#9333ea',
      light: '#f3e8ff'
    },
    {
      id: 'theme-slate-charcoal',
      color: '#334155',
      light: '#e2e8f0'
    },
    {
      id: 'theme-ocean-cyan',
      color: '#0e7490',
      light: '#cffafe'
    },
    {
      id: 'theme-candy-pink',
      color: '#db2777',
      light: '#fce7f3'
    },
    {
      id: 'theme-earth-brown',
      color: '#78350f',
      light: '#fef3c7'
    },
    {
      id: 'theme-wheat-yellow',
      color: '#ca8a04',
      light: '#fef9c3'
    },
    {
      id: 'theme-silver-grey',
      color: '#4b5563',
      light: '#f3f4f6'
    },
    {
      id: 'theme-supermarket-red',
      color: '#dc2626',
      light: '#fee2e2'
    },
    {
      id: 'theme-mint-turquoise',
      color: '#0d9488',
      light: '#ccfbf1'
    },
    {
      id: 'theme-orchid-violet',
      color: '#7c3aed',
      light: '#ede9fe'
    },
    {
      id: 'theme-lime-green',
      color: '#65a30d',
      light: '#ecfccb'
    },
    {
      id: 'theme-denim-blue',
      color: '#2563eb',
      light: '#dbeafe'
    },
    {
      id: 'theme-material-light-blue',
      color: '#039be5',
      light: '#e1f5fe'
    }
  ].freeze

  IDS = ALL.pluck(:id).freeze

  class << self
    def all
      ALL
    end

    def ids
      IDS
    end

    def exists?(id)
      IDS.include?(id)
    end

    def find(id)
      ALL.find { |theme| theme[:id] == id }
    end
  end
end
