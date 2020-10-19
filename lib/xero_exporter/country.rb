# frozen_string_literal: true

require 'json'

module XeroExporter
  class Country

    CODES_TO_NAMES = JSON.parse(File.read(File.expand_path('../../resource/country-codes.json', __dir__)))

    attr_reader :code

    def initialize(code)
      @code = code
    end

    def to_s
      @code
    end

    def name
      CODES_TO_NAMES[@code.upcase] || @code.upcase
    end

    def eql?(other)
      @code == other.code
    end

    def hash
      @code.hash
    end

  end
end
