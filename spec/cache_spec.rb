RSpec.describe REDCap::Cache do
  let(:url) { "https://redcap.example.com/api/?content=record&format=json" }
  let(:cache_dir) { "tmp/redcap_cache" }
  let(:cache_key) { Digest::MD5.hexdigest(url) }
  let(:cache_path) { "#{cache_dir}/#{cache_key}" }
  let(:test_data) { "cached response data" }

  before do
    # Clean up any existing cache
    FileUtils.rm_rf(cache_dir) if File.exist?(cache_dir)
    REDCap.cache = nil
  end

  after do
    # Clean up cache after tests
    FileUtils.rm_rf(cache_dir) if File.exist?(cache_dir)
  end

  describe ".fetch" do
    context "when caching is disabled" do
      before { REDCap.cache = false }

      it "executes block and returns result without caching" do
        result = REDCap::Cache.fetch(url) { test_data }

        expect(result).to eq(test_data)
        expect(File.exist?(cache_path)).to be false
      end
    end

    context "when caching is enabled" do
      before { REDCap.cache = true }

      context "when cache file does not exist" do
        it "executes block, caches result, and returns data" do
          result = REDCap::Cache.fetch(url) { test_data }

          expect(result).to eq(test_data)
          expect(File.exist?(cache_path)).to be true
          expect(File.read(cache_path)).to eq(test_data)
        end

        it "creates cache directory if it doesn't exist" do
          expect(File.exist?(cache_dir)).to be false

          REDCap::Cache.fetch(url) { test_data }

          expect(File.exist?(cache_dir)).to be true
        end
      end

      context "when cache file exists" do
        before do
          FileUtils.mkdir_p(cache_dir)
          File.write(cache_path, test_data)
        end

        it "returns cached data without executing block" do
          block_executed = false
          result = REDCap::Cache.fetch(url) { block_executed = true; "new data" }

          expect(result).to eq(test_data)
          expect(block_executed).to be false
        end
      end
    end

    context "when REDCap.cache is nil" do
      before { REDCap.cache = nil }

      it "executes block without caching" do
        result = REDCap::Cache.fetch(url) { test_data }

        expect(result).to eq(test_data)
        expect(File.exist?(cache_path)).to be false
      end
    end
  end

  describe ".clear" do
    before do
      FileUtils.mkdir_p(cache_dir)
      File.write("#{cache_dir}/test_file", "test content")
    end

    it "removes entire cache directory" do
      expect(File.exist?(cache_dir)).to be true

      REDCap::Cache.clear

      expect(File.exist?(cache_dir)).to be false
    end

    context "when cache directory doesn't exist" do
      before { FileUtils.rm_rf(cache_dir) }

      it "doesn't raise error" do
        expect { REDCap::Cache.clear }.not_to raise_error
      end
    end
  end

  describe "cache key generation" do
    it "generates consistent MD5 hash for same URL" do
      key1 = Digest::MD5.hexdigest(url)
      key2 = Digest::MD5.hexdigest(url)

      expect(key1).to eq(key2)
      expect(key1).to match(/\A[a-f0-9]{32}\z/)
    end

    it "generates different hashes for different URLs" do
      url1 = "https://redcap.example.com/api/?content=record"
      url2 = "https://redcap.example.com/api/?content=metadata"

      key1 = Digest::MD5.hexdigest(url1)
      key2 = Digest::MD5.hexdigest(url2)

      expect(key1).not_to eq(key2)
    end
  end
end