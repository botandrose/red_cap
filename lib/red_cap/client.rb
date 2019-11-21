require "json"
require "faraday"

class REDCap
  class Client
    def initialize url: REDCap.url, token: REDCap.token, per_page: REDCap.per_page
      @url = url
      @token = token
      @per_page = per_page
    end

    def records filter=nil
      enumerator = fetch_study_ids(filter).in_groups_of(@per_page, false)
      if block_given?
        enumerator.each do |study_ids|
          json_api_request(content: "record", records: study_ids.join(",")).each do |record|
            yield record
          end
        end
      else
        enumerator.flat_map do |study_ids|
          json_api_request(content: "record", records: study_ids.join(","))
        end
      end
    end

    def find_record study_id
      json_api_request(content: "record", records: study_id).first
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

    def fetch_study_ids filter=nil
      json_api_request(content: "record", fields: "study_id", filterLogic: filter)
        .map { |hash| hash["study_id"] }
    end

    def json_api_request options
      response = base_request(options.reverse_merge({
        format: "json",
      }))
      JSON.load(response.body)
    end

    def base_request options
      connection = Faraday.new(url: @url)
      connection.options.open_timeout = 300
      connection.options.timeout = 300
      response = connection.post nil, options.reverse_merge(token: @token)
      if error_message = response.body[/<error>(.+?)<\/error>/, 1]
        raise Error.new(error_message)
      end
      response
    end

    class Error < StandardError; end
  end
end
