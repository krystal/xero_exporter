# frozen_string_literal: true

require 'spec_helper'
require 'xero_exporter/country'

describe XeroExporter::Country do
  context 'with a country code' do
    subject(:country) { described_class.new('GB') }

    context '#name' do
      it 'returns the name' do
        expect(country.name).to eq 'United Kingdom'
      end
    end

    context '#code' do
      it 'returns the code' do
        expect(country.code).to eq 'GB'
      end
    end

    context '#to_s' do
      it 'returns the code' do
        expect(country.to_s).to eq 'GB'
      end
    end

    context '#eql?' do
      it 'is equal to another country with the same code' do
        expect(country).to eql described_class.new('GB')
      end

      it 'is not equal to another country with a different code' do
        expect(country).not_to eql described_class.new('FR')
      end
    end

    context '#hash' do
      it 'produces the same hash for the same code' do
        expect(country.hash).to eq described_class.new('GB').hash
      end
    end
  end

  context 'with a nil country code' do
    subject(:country) { described_class.new(nil) }

    context '#name' do
      it 'returns nil' do
        expect(country.name).to be_nil
      end
    end

    context '#code' do
      it 'returns nil' do
        expect(country.code).to be_nil
      end
    end

    context '#to_s' do
      it 'returns nil' do
        expect(country.to_s).to be_nil
      end
    end

    context '#eql?' do
      it 'is equal to another country with a nil code' do
        expect(country).to eql described_class.new(nil)
      end

      it 'is not equal to a country with a code' do
        expect(country).not_to eql described_class.new('GB')
      end
    end

    context '#hash' do
      it 'produces the same hash for nil codes' do
        expect(country.hash).to eq described_class.new(nil).hash
      end
    end
  end
end
