# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'
require Rails.root.join('db/seeds/seed_console')
require Rails.root.join('db/seeds/sat_catalogs')
require Rails.root.join('db/seeds/sat_catalog_csv')

RSpec.describe 'SAT catalog seeds', type: :model do
  it 'loads all 18 SAT month and bimonthly keys while retaining a 601 regime' do
    SatCatalogSeeds.seed!

    expect(SatMonth.order(:month_number).pluck(:code)).to eq((1..18).map { |number| format('%02d', number) })
    expect(SatMonth.find_by!(code: '18').description).to eq('Noviembre-Diciembre')
    expect(SatFiscalRegime.find_by!(code: '601').person_type).to eq('M')
    expect(SatFiscalRegime.find_by!(code: '626').applies_to_company).to be(true)
    expect(SatFiscalRegime.for_person('M')).to include(SatFiscalRegime.find_by!(code: '626'))
    expect(SatPaymentMethodType.order(:code).pluck(:code)).to include('PUE', 'PPD')
    expect(SatPaymentMethod.find_by!(code: '03').description).to include('Transferencia')
    expect(SatCfdiUse.find_by!(code: 'G03').description).to eq('Gastos en general')
  end

  it 'does not overwrite edited values or duplicate rows when run repeatedly' do
    SatCatalogSeeds.seed!
    bank = SatBank.find_by!(code: '012')
    bank.update!(name: 'Nombre personalizado')
    counts = [SatBank.count, SatMonth.count, SatCfdiUse.count, SatFiscalRegime.count]

    SatCatalogSeeds.seed!

    expect(bank.reload.name).to eq('Nombre personalizado')
    expect([SatBank.count, SatMonth.count, SatCfdiUse.count, SatFiscalRegime.count]).to eq(counts)
  end

  it 'does not resurrect manually archived SAT catalog entries' do
    SatCatalogSeeds.seed!
    currency = SatCurrency.find_by!(code: 'EUR')
    currency.destroy!

    SatCatalogSeeds.seed!

    expect(SatCurrency.with_deleted.where(code: 'EUR').count).to eq(1)
    expect(SatCurrency.find_by(code: 'EUR')).to be_nil
  end

  it 'imports normalized CSV records and skips their keys on the next run' do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, 'sat_product_service_keys.csv'), <<~CSV)
        code,description,status
        01010101,Clave de prueba,true
      CSV

      expect(SatCatalogCsv.seed!(directory:)).to eq(nil)
      record = SatProductServiceKey.find_by!(code: '01010101')
      expect(record.description).to eq('Clave de prueba')
      record.update!(description: 'Modificado manualmente')

      SatCatalogCsv.seed!(directory:)

      expect(SatProductServiceKey.where(code: '01010101').count).to eq(1)
      expect(record.reload.description).to eq('Modificado manualmente')
    end
  end

  it 'rejects unknown CSV columns instead of silently importing garbage' do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, 'sat_voucher_types.csv'), <<~CSV)
        code,description,unknown_column
        I,Ingreso,unexpected
      CSV
      expect { SatCatalogCsv.seed!(directory:) }.to raise_error(ArgumentError, /columnas no admitidas/)
    end
  end

  it 'rejects missing required CSV fields' do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, 'sat_product_service_keys.csv'), <<~CSV)
        code
        01010101
      CSV
      expect { SatCatalogCsv.seed!(directory:) }.to raise_error(ArgumentError, /faltan columnas/)
    end
  end

  it 'rejects empty source keys with the originating CSV path' do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, 'sat_voucher_types.csv'), <<~CSV)
        code,description
        ,Sin clave
      CSV
      expect { SatCatalogCsv.seed!(directory:) }.to raise_error(ArgumentError, /clave vacía/)
    end
  end

  it 'keeps previously archived codes when importing official CSV rows' do
    archived = SatVoucherType.create!(code: 'I', description: 'Histórico')
    archived.destroy!

    Dir.mktmpdir do |directory|
      File.write(File.join(directory, 'sat_voucher_types.csv'), <<~CSV)
        code,description
        I,Ingreso
      CSV
      SatCatalogCsv.seed!(directory:)
    end

    expect(SatVoucherType.with_deleted.where(code: 'I').count).to eq(1)
    expect(SatVoucherType.find_by(code: 'I')).to be_nil
  end
end
