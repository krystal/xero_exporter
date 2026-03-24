# frozen_string_literal: true

require 'spec_helper'
require 'xero_exporter/tax_rate'
require 'xero_exporter/country'

describe XeroExporter::TaxRate do
  context '#xero_name' do
    context 'with a country' do
      let(:country) { XeroExporter::Country.new('GB') }

      it 'returns the correct name for a normal tax rate' do
        tax_rate = described_class.new(20.0, :normal)
        expect(tax_rate.xero_name(country)).to eq 'Tax for GB (20.0%)'
      end

      it 'returns the correct name for a none tax rate' do
        tax_rate = described_class.new(0.0, :none)
        expect(tax_rate.xero_name(country)).to eq 'No tax (0.0%)'
      end

      it 'returns the correct name for a moss tax rate' do
        tax_rate = described_class.new(21.0, :moss)
        expect(tax_rate.xero_name(country)).to eq 'MOSS United Kingdom 21.0%'
      end

      it 'returns the correct name for a reverse charge tax rate' do
        tax_rate = described_class.new(0.0, :reverse_charge)
        expect(tax_rate.xero_name(country)).to eq 'Reverse Charge (GB)'
      end

      it 'returns the correct name for an ec_services tax rate' do
        tax_rate = described_class.new(20.0, :ec_services)
        expect(tax_rate.xero_name(country)).to eq 'EC Services for GB (20.0%)'
      end
    end

    context 'without a country' do
      let(:country) { XeroExporter::Country.new(nil) }

      it 'returns the correct name for a normal tax rate' do
        tax_rate = described_class.new(20.0, :normal)
        expect(tax_rate.xero_name(country)).to eq 'Tax (20.0%)'
      end

      it 'returns the correct name for a none tax rate' do
        tax_rate = described_class.new(0.0, :none)
        expect(tax_rate.xero_name(country)).to eq 'No tax (0.0%)'
      end

      it 'returns the correct name for an ec_services tax rate' do
        tax_rate = described_class.new(20.0, :ec_services)
        expect(tax_rate.xero_name(country)).to eq 'EC Services (20.0%)'
      end
    end

    context 'with a custom name' do
      let(:country) { XeroExporter::Country.new(nil) }

      it 'returns the custom name with the rate suffixed' do
        tax_rate = described_class.new(20.0, :normal, 'My Custom Tax')
        expect(tax_rate.xero_name(country)).to eq 'My Custom Tax (20.0%)'
      end
    end
  end

  context '#xero_report_type' do
    it 'returns MOSSSALES for moss' do
      expect(described_class.new(21.0, :moss).xero_report_type).to eq 'MOSSSALES'
    end

    it 'returns ECOUTPUTSERVICES for ec_services' do
      expect(described_class.new(20.0, :ec_services).xero_report_type).to eq 'ECOUTPUTSERVICES'
    end

    it 'returns OUTPUT for other types' do
      expect(described_class.new(20.0, :normal).xero_report_type).to eq 'OUTPUT'
    end
  end

  context '#eql?' do
    it 'is equal when rate and type match' do
      expect(described_class.new(20.0, :normal)).to eql described_class.new(20.0, :normal)
    end

    it 'is not equal when rate differs' do
      expect(described_class.new(20.0, :normal)).not_to eql described_class.new(21.0, :normal)
    end

    it 'is not equal when type differs' do
      expect(described_class.new(20.0, :normal)).not_to eql described_class.new(20.0, :moss)
    end

    it 'is equal when rate, type and name all match' do
      expect(described_class.new(20.0, :normal, 'Custom')).to eql described_class.new(20.0, :normal, 'Custom')
    end

    it 'is not equal when name differs' do
      expect(described_class.new(20.0, :normal, 'A')).not_to eql described_class.new(20.0, :normal, 'B')
    end

    it 'is not equal when one has a name and the other does not' do
      expect(described_class.new(20.0, :normal, 'Custom')).not_to eql described_class.new(20.0, :normal)
    end
  end
end
