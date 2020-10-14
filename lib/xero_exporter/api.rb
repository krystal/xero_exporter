# frozen_string_literal: true

require 'net/http'
require 'json'

module XeroExporter
  class API

    class APIConnectionError < Error
    end

    class APIError < Error

      attr_reader :status, :body

      def initialize(status, message, body = nil)
        @status = status
        @message = message
        @body = body
      end

      def message
        to_s
      end

      def to_s
        "[#{@status}] #{@message}"
      end

    end

    METHOD_MAP = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      put: Net::HTTP::Put
    }.freeze

    def initialize(access_token, tenant_id)
      @access_token = access_token
      @tenant_id = tenant_id
    end

    def get(path, params = {})
      request(:get, path, params)
    end

    def post(path, params = {})
      request(:post, path, params)
    end

    def put(path, params = {})
      request(:put, path, params)
    end

    private

    def request(method, path, params = {})
      http = Net::HTTP.new('api.xero.com', 443)
      http.use_ssl = true

      path = "/api.xro/2.0/#{path}"

      if method == :get && !params.empty?
        query_string = URI.encode_www_form(params)
        path = "#{path}?#{query_string}"
      end

      request = METHOD_MAP[method].new(path)
      request['Authorization'] = "Bearer #{@access_token}"
      request['Xero-Tenant-ID'] = @tenant_id
      request['Accept'] = 'application/json'

      if method != :get && !params.empty?
        request['Content-Type'] = 'application/json'
        request.body = params.to_json
      end

      logger.debug "[#{method.to_s.upcase}] to #{path}"
      response = make_request_with_error_handling(http, request)

      if response.is_a?(Net::HTTPOK)
        logger.debug 'Status: 200 OK'
        JSON.parse(response.body)
      elsif response.code.to_i == 429
        logger.debug 'Status: 429 Rate Limit Exceeded'
        handle_retry(response, method, path, params)
      else
        handle_error(response)
      end
    end

    def make_request_with_error_handling(http, request)
      http.request(request)
    rescue StandardError => e
      logger.error "#{e.class}: #{e.message}"
      raise APIConnectionError, "#{e.class}: #{e.message}"
    end

    def handle_retry(response, method, path, params)
      problem = response['X-Rate-Limit-Problem']
      if problem != 'minute'
        raise APIConnectionError, "Rate limit exceeded (retry not possible) (problem: #{problem})"
      end

      retry_after = response['Retry-After'].to_i + 2
      logger.debug "Waiting #{retry_after} seconds"
      sleep retry_after

      logger.debug 'Retrying after rate limit pause'
      request(method, path, params)
    end

    def handle_error(response)
      logger.error "Status: #{response.code}"
      logger.debug response.body

      if response['Content-Type'] =~ /application\/json/
        json = JSON.parse(response.body)
        logger.debug 'Error was JSON encoded'
        raise APIError.new(response.code.to_i, "#{json['Type']}: #{json['Message']}", response.body)
      end

      raise APIError.new(response.code.to_i, response.body)
    end

    def logger
      XeroExporter.logger
    end

  end
end
