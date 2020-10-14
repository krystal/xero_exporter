# frozen_string_literal: true

require 'logger'

module XeroExporter

  class << self

    attr_writer :logger

    def logger
      @logger ||= Logger.new($stdout)
    end

  end

end
