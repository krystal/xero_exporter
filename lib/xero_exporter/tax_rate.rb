# frozen_string_literal: true

module XeroExporter
  class TaxRate

    attr_reader :rate
    attr_reader :type

    def initialize(rate, type)
      @rate = rate&.to_f
      @type = type
    end

    def eql?(other)
      @rate == other.rate && @type == other.type
    end

    def hash
      [@rate, @type].hash
    end

  end
end
