# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Fiscal and inventory branching safety', type: :service do
  describe AccountsPayable::SatStatusVerifier do
    let(:invoice) { double('Invoice') }
    let(:verifier) { described_class.new(invoice:) }

    it 'rejects an unavailable or oversized SAT response' do
      [nil, '', 'A' * 70.kilobytes].each do |xml|
        expect { verifier.send(:valid_sat_document, xml) }
          .to raise_error(ArgumentError, /Invalid SAT response/)
      end
    end

    it 'rejects SOAP faults and accepts a valid SOAP document' do
      expect { verifier.send(:valid_sat_document, '<Envelope><Fault>Failed</Fault></Envelope>') }
        .to raise_error(ArgumentError, /Invalid SAT response/)
      expect { verifier.send(:valid_sat_document, '<Envelope/>') }.to be_a(Nokogiri::XML::Document)
    end

    it 'rejects a valid response that reports cancellation' do
      xml = '<ConsultaResponse><CodigoEstatus>S - Correcto</CodigoEstatus><Estado>Cancelado</Estado></ConsultaResponse>'
      expect { verifier.send(:parse_response, xml) }
        .to raise_error(ArgumentError, /not valid according to SAT/)
    end

    it 'accepts a vigente response with a code' do
      xml = '<ConsultaResponse><CodigoEstatus>S - Correcto</CodigoEstatus><Estado>Vigente</Estado></ConsultaResponse>'
      expect(verifier.send(:parse_response, xml)).to include(status: 'Vigente', code: 'S - Correcto')
    end
  end

  describe AccountsPayable::CfdiParser do
    it 'rejects DTD declarations even inside otherwise legitimate-looking input' do
      expect { described_class.validate_input!('<!DOCTYPE Comprobante>') }
        .to raise_error(ArgumentError, /DTD declarations/)
      expect { described_class.validate_input!('<!ENTITY x "hello">') }
        .to raise_error(ArgumentError, /DTD declarations/)
    end

    it 'accepts short XML without DTD declarations' do
      expect { described_class.validate_input!('<Comprobante/>') }.not_to raise_error
    end

    it 'rejects a CFDI with wrong receipt type' do
      xml = '<cfdi:Comprobante xmlns:cfdi="http://www.sat.gob.mx/cfd/4" Version="4.0" TipoDeComprobante="E"/>'
      root = Nokogiri::XML(xml).root
      expect { described_class.validate_comprobante!(root, 'I') }
        .to raise_error(ArgumentError, /Incorrect CFDI type/)
    end
  end

  describe InventoryMovement do
    it 'rejects a cross-organization movement and accepts matching inventory' do
      movement = described_class.new(organization_id: 1)
      allow(movement).to receive(:inventory).and_return(double(organization_id: 2))
      movement.send(:same_organization)
      expect(movement.errors[:inventory]).not_to be_empty

      movement.errors.clear
      allow(movement).to receive(:inventory).and_return(double(organization_id: 1))
      movement.send(:same_organization)
      expect(movement.errors[:inventory]).to be_empty
    end

    it 'rejects updates to immutable movement records' do
      movement = described_class.new
      expect { movement.send(:prevent_mutations) }.to throw_symbol(:abort)
      expect(movement.errors[:base]).not_to be_empty
    end
  end
end
