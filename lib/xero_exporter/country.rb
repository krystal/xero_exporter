# frozen_string_literal: true

module XeroExporter
  class Country

    attr_reader :code

    def initialize(code)
      @code = code
    end

    def eql?(other)
      @code == other.code
    end

    def hash
      @code.hash
    end

  end
end
