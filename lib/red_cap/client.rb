require "json"
require "faraday"

module REDCap
  class Client
    def initialize url: REDCap.url, token: REDCap.token
      @url = url
      @token = token
    end

    def records
      json_api_request(content: "record")
    end

    def metadata
      json_api_request(content: "metadata")
    end

    def file record_id, file_id
      response = base_request({
        content: "file",
        action: "export",
        record: record_id,
        field: file_id,
      })
      _, type, filename = *response.headers["content-type"].match(/\A(.+); name=\"(.+)\"\z/)
      File.new(response.body, type, filename)
    end

    File = Struct.new(:data, :type, :filename)

    private

    def json_api_request options
      response = base_request(options.reverse_merge({
        format: "json",
      }))
      JSON.load(response.body)
    end

    def base_request options
      connection = Faraday.new(url: @url)
      response = connection.post(nil, options.reverse_merge({
        token: @token,
      }))
      if error_message = response.body[/<error>(.+?)<\/error>/, 1]
        raise Error.new(error_message)
      end
      response
    end

    class Error < StandardError; end
  end
end
