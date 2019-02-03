require "red_cap/version"
require "red_cap/client"
require "red_cap/form"

module REDCap
  class << self
    def configure
      yield self
    end

    attr_accessor :url, :token
  end
end

