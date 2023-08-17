require "red_cap/version"
require "red_cap/client"
require "red_cap/form"

class REDCap
  class << self
    def configure
      yield self
    end

    attr_accessor :url, :token, :per_page, :cache

    def per_page
      @per_page ||= 100
    end
  end

  def initialize url: REDCap.url, token: REDCap.token, per_page: REDCap.per_page
    @url = url
    @token = token
    @per_page = per_page
  end

  attr_accessor :url, :token, :per_page

  def form
    @form ||= Form.new(client.metadata)
  end

  def find study_id
    client.find_record study_id
  end

  def all &block
    client.records &block
  end

  def where conditions, &block
    filters = conditions.reduce([]) do |filters, (field, value)|
      filters << "[#{field}]=#{value}"
    end
    client.records(filters.join(" AND "), &block)
  end

  def update study_id, attributes
    record = attributes.merge(study_id: study_id).stringify_keys
    client.save_records [record]
  end

  def delete study_id
    client.delete_records [study_id]
  end

  def client
    @client ||= Client.new(url: url, token: token, per_page: per_page)
  end
end

