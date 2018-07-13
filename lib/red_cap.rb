require "red_cap/version"
require "red_cap/client"
require "red_cap/form"

module REDCap
  def self.configure
    yield self
  end

  cattr_accessor :url, :token
end

