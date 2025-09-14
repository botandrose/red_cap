RSpec.describe REDCap::Client do
  let(:url) { "https://redcap.example.com/api/" }
  let(:token) { "test_token_123" }
  let(:client) { REDCap::Client.new(url: url, token: token, per_page: 50) }
  let(:connection) { instance_double(Faraday::Connection) }
  let(:response) { instance_double(Faraday::Response, body: '[]') }

  before do
    allow(Faraday).to receive(:new).and_return(connection)
    allow(connection).to receive(:options).and_return(double("options", open_timeout: nil, timeout: nil))
    allow(connection.options).to receive(:open_timeout=)
    allow(connection.options).to receive(:timeout=)
    allow(connection).to receive(:post).and_return(response)
  end

  describe "#initialize" do
    it "accepts configuration parameters" do
      expect(client.instance_variable_get(:@url)).to eq(url)
      expect(client.instance_variable_get(:@token)).to eq(token)
      expect(client.instance_variable_get(:@per_page)).to eq(50)
    end

    it "uses global configuration when no parameters given" do
      REDCap.url = url
      REDCap.token = token
      REDCap.per_page = 75

      client = REDCap::Client.new
      expect(client.instance_variable_get(:@url)).to eq(url)
      expect(client.instance_variable_get(:@token)).to eq(token)
      expect(client.instance_variable_get(:@per_page)).to eq(75)
    end
  end

  describe "#records" do
    let(:study_ids) { ["001", "002", "003"] }
    let(:records) { [{"study_id" => "001"}, {"study_id" => "002"}] }

    before do
      allow(client).to receive(:fetch_study_ids).and_return(study_ids)
      allow(client).to receive(:json_api_request).and_return(records)
      allow(study_ids).to receive(:in_groups_of).with(50, false).and_return([study_ids])
    end

    context "without block" do
      it "returns all records as array" do
        result = client.records

        expect(result).to eq(records)
        expect(client).to have_received(:fetch_study_ids).with(nil)
        expect(client).to have_received(:json_api_request).with(
          content: "record",
          records: "001,002,003"
        )
      end
    end

    context "with block" do
      it "yields records in batches" do
        yielded_records = []
        client.records { |record| yielded_records << record }

        expect(yielded_records).to eq(records)
      end
    end

    context "with filter" do
      it "passes filter to fetch_study_ids" do
        filter = "[status]=1"
        client.records(filter)

        expect(client).to have_received(:fetch_study_ids).with(filter)
      end
    end
  end

  describe "#find_record" do
    let(:record) { {"study_id" => "001", "name" => "John"} }

    before do
      allow(client).to receive(:json_api_request).and_return([record])
    end

    it "returns the first record from API response" do
      result = client.find_record("001")

      expect(result).to eq(record)
      expect(client).to have_received(:json_api_request).with(
        content: "record",
        records: "001"
      )
    end
  end

  describe "#save_records" do
    let(:records) { [{"study_id" => "001", "name" => "John"}] }

    before do
      allow(client).to receive(:json_api_request)
    end

    it "sends records as JSON to API" do
      client.save_records(records)

      expect(client).to have_received(:json_api_request).with(
        content: "record",
        data: records.to_json,
        overwriteBehavior: "overwrite"
      )
    end
  end

  describe "#delete_records" do
    let(:study_ids) { ["001", "002"] }

    before do
      allow(client).to receive(:json_api_request)
    end

    it "deletes records by study_ids" do
      client.delete_records(study_ids)

      expect(client).to have_received(:json_api_request).with(
        content: "record",
        action: "delete",
        records: study_ids
      )
    end
  end

  describe "#metadata" do
    let(:metadata) { [{"field_name" => "study_id", "field_type" => "text"}] }

    before do
      allow(client).to receive(:json_api_request).and_return(metadata)
    end

    it "fetches metadata from API" do
      result = client.metadata

      expect(result).to eq(metadata)
      expect(client).to have_received(:json_api_request).with(content: "metadata")
    end
  end

  describe "#file" do
    let(:file_response) { instance_double(Faraday::Response) }
    let(:headers) { {"content-type" => "image/png; name=\"test.png\""} }

    before do
      allow(file_response).to receive(:body).and_return("file_data")
      allow(file_response).to receive(:headers).and_return(headers)
      allow(client).to receive(:base_request).and_return(file_response)
    end

    it "downloads file and returns File struct" do
      result = client.file("001", "photo")

      expect(result).to be_a(REDCap::Client::File)
      expect(result.data).to eq("file_data")
      expect(result.type).to eq("image/png")
      expect(result.filename).to eq("test.png")

      expect(client).to have_received(:base_request).with({
        content: "file",
        action: "export",
        record: "001",
        field: "photo",
        event: nil
      })
    end

    it "accepts event parameter" do
      client.file("001", "photo", event: "baseline_arm_1")

      expect(client).to have_received(:base_request).with({
        content: "file",
        action: "export",
        record: "001",
        field: "photo",
        event: "baseline_arm_1"
      })
    end
  end

  describe "#fetch_study_ids" do
    let(:records) { [{"study_id" => "001"}, {"study_id" => "002"}] }

    before do
      allow(client).to receive(:json_api_request).and_return(records)
    end

    it "extracts study_ids from records" do
      result = client.fetch_study_ids

      expect(result).to eq(["001", "002"])
      expect(client).to have_received(:json_api_request).with({
        content: "record",
        fields: "study_id",
        filterLogic: nil
      })
    end

    it "passes filter to API request" do
      filter = "[status]=1"
      client.fetch_study_ids(filter)

      expect(client).to have_received(:json_api_request).with({
        content: "record",
        fields: "study_id",
        filterLogic: filter
      })
    end
  end

  describe "#json_api_request" do
    let(:options) { {content: "record"} }
    let(:json_response) { '[{"study_id": "001"}]' }

    before do
      allow(response).to receive(:body).and_return(json_response)
      allow(client).to receive(:base_request).and_return(response)
      allow(JSON).to receive(:load).with(json_response).and_return([{"study_id" => "001"}])
    end

    it "makes request and parses JSON response" do
      result = client.json_api_request(options)

      expect(result).to eq([{"study_id" => "001"}])
      expect(client).to have_received(:base_request).with(options.merge(format: "json"))
      expect(JSON).to have_received(:load).with(json_response)
    end

    context "with caching enabled" do
      let(:full_url) { "#{url}?content=record&format=json" }

      before do
        allow(REDCap::Cache).to receive(:fetch).and_yield.and_return(json_response)
        allow(options).to receive(:to_query).and_return("content=record&format=json")
      end

      it "uses cache when enabled" do
        result = client.json_api_request(options, cache: true)

        expect(result).to eq([{"study_id" => "001"}])
        expect(REDCap::Cache).to have_received(:fetch).with(full_url)
      end
    end
  end

  describe "base_request" do
    let(:options) { {content: "record"} }

    it "creates Faraday connection with timeouts" do
      client.send(:base_request, options)

      expect(Faraday).to have_received(:new).with(url: url)
      expect(connection.options).to have_received(:open_timeout=).with(300)
      expect(connection.options).to have_received(:timeout=).with(300)
      expect(connection).to have_received(:post).with(nil, options.merge(token: token))
    end

    context "when API returns error" do
      before do
        allow(response).to receive(:body).and_return('{"error":"Invalid token"}')
      end

      it "raises Error with response body" do
        expect {
          client.send(:base_request, options)
        }.to raise_error(REDCap::Client::Error, '{"error":"Invalid token"}')
      end
    end
  end
end