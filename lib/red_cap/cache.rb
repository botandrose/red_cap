class REDCap
  class Cache
    def self.fetch url, &block
      key = Digest::MD5.hexdigest(url)

      dir = "tmp/redcap_cache"
      path = dir + "/#{key}"

      if REDCap.cache && ::File.exist?(path)
        ::File.read(path)
      else
        raw = block.call

        if REDCap.cache
          FileUtils.mkdir_p dir
          ::File.write(path, raw)
        end
        raw
      end
    end
  end
end

