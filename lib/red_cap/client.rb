require "json"
require "faraday"
require "red_cap/cache"

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

    def save_records records
      json_api_request(content: "record", data: records.to_json, overwriteBehavior: "overwrite")
    end

    def delete_records study_ids
      json_api_request(content: "record", action: "delete", records: study_ids)
    end

    def metadata
      json_api_request(content: "metadata")
    end

    def file record_id, file_id, event: nil
      response = base_request({
        content: "file",
        action: "export",
        record: record_id,
        field: file_id,
        event: event,
      })
      _, type, filename = *response.headers["content-type"].match(/\A(.+); name=\"(.+)\"/)
      File.new(response.body, type, filename)
    end

    File = Struct.new(:data, :type, :filename)

    def fetch_study_ids filter=nil
      json_api_request({
        content: "record",
        fields: "study_id",
        filterLogic: filter,
      }).map { |hash| hash["study_id"] }
    end

    require "active_support/core_ext/object/to_query"
    def json_api_request options, cache: false
      request_options = options.reverse_merge(format: "json")
      json = if cache
        full_url = @url + "?" + options.to_query
        Cache.fetch(full_url) do
          base_request(request_options).body
        end
      else
        base_request(request_options).body
      end
      JSON.load(json)
    end

    private

    def base_request options
      connection = Faraday.new(url: @url)
      connection.options.open_timeout = 300
      connection.options.timeout = 300
      response = connection.post nil, options.reverse_merge(token: @token)
      if response.body =~ /^{"error":"/
        raise Error.new(response.body)
      end
      response
    end

    class Error < StandardError; end
  end
end
