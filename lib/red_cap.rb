require "red_cap/version"
require "red_cap/client"
require "red_cap/form"

class REDCap
  class << self
    def configure
      yield self
    end

    attr_accessor :url, :token, :per_page

    def per_page
      @per_page ||= 100
    end
  end

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

  private

  def client
    @client ||= Client.new
  end
end

