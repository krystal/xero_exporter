# frozen_string_literal: true

module XeroExporter
  class TaxRate

    attr_reader :rate
    attr_reader :type
    attr_reader :name

    def initialize(rate, type, name = nil)
      @rate = rate.to_f
      @type = type
      @name = name
    end

    def to_s
      "#{@rate}[#{@type}]"
    end

    def eql?(other)
      @rate == other.rate && @type == other.type && @name == other.name
    end

    def hash
      [@rate, @type, @name].hash
    end

    def xero_name(country)
      return "#{@name} (#{@rate}%)" if @name

      case @type
      when :none
        "No tax (#{@rate}%)"
      when :moss
        "MOSS #{country.name} #{@rate}%"
      when :reverse_charge
        "Reverse Charge (#{country.code})"
      when :ec_services
        if country.code
          "EC Services for #{country.code} (#{@rate}%)"
        else
          "EC Services (#{@rate}%)"
        end
      else
        if country.code
          "Tax for #{country.code} (#{@rate}%)"
        else
          "Tax (#{@rate}%)"
        end
      end
    end

    def xero_report_type
      return 'MOSSSALES' if @type == :moss
      return 'ECOUTPUTSERVICES' if @type == :ec_services

      'OUTPUT'
    end

  end
end
