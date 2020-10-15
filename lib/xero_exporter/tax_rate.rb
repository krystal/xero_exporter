# frozen_string_literal: true

module XeroExporter
  class TaxRate

    attr_reader :rate
    attr_reader :type

    def initialize(rate, type)
      @rate = rate&.to_f || 0.0
      @type = type
    end

    def to_s
      "#{@rate}[#{@type}]"
    end

    def eql?(other)
      @rate == other.rate && @type == other.type
    end

    def hash
      [@rate, @type].hash
    end

    def xero_name(country)
      case @type
      when :moss
        "MOSS for #{country.code} (#{@rate}%)"
      when :reverse_charge
        "Reverse Charge (#{country.code})"
      when :ec_services
        "EC Services for #{country.code} (#{@rate}%)"
      else
        "Tax for #{country.code} (#{@rate}%)"
      end
    end

    def xero_report_type
      return 'MOSSSALES' if @type == :moss
      return 'ECOUTPUTSERVICES' if @type == :ec_services

      'OUTPUT'
    end

  end
end
