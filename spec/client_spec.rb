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
        event: nil,
        repeat_instance: nil,
      })
    end

    it "accepts event parameter" do
      client.file("001", "photo", event: "baseline_arm_1")

      expect(client).to have_received(:base_request).with({
        content: "file",
        action: "export",
        record: "001",
        field: "photo",
        event: "baseline_arm_1",
        repeat_instance: nil,
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

    context "when REDCap sends something other than JSON" do
      let(:json_response) { "Service Unavailable:\n  REDCap is down for maintenance#{" until further notice" * 20}" }

      before do
        allow(JSON).to receive(:load).and_call_original
      end

      it "raises a JSON::ParserError that quotes the start of the body" do
        expect {
          client.json_api_request(options)
        }.to raise_error(REDCap::Client::NonJSONResponseError, %r{\AREDCap sent a response that isn't JSON: Service Unavailable: REDCap is down for maintenance until further notice.{100,}\.\.\.\z}) { |error|
          expect(error).to be_a(JSON::ParserError)
          expect(error).not_to be_a(REDCap::Client::Error)
        }
      end
    end

    context "when REDCap sends its red HTML error box" do
      let(:json_response) { <<~HTML }
        <div style="font: normal 12px Verdana, Arial;padding:20px;border: 1px solid red;color: #800000;max-width: 600px;background: #FFE1E1;">
          <div style="font-weight:bold;font-size:15px;padding-bottom:5px;">
            REDCap crashed due to an unexpected error!
          </div>
          <div>
            <b>Error message:</b> You don&#039;t have the &quot;API Export&quot; right &amp; can&#39;t export instruments.<br>
            <b>File:</b> /var/www/redcap/redcap_v15.5.20/API/index.php<br>
            <b>Line:</b> 42
          </div>
        </div>
      HTML

      before do
        allow(JSON).to receive(:load).and_call_original
      end

      it "raises with the box's text, stripped of markup, so the reason survives truncation" do
        expect {
          client.json_api_request(options)
        }.to raise_error(REDCap::Client::NonJSONResponseError, %(REDCap sent an HTML error instead of JSON: REDCap crashed due to an unexpected error! Error message: You don't have the "API Export" right & can't export instruments. File: /var/www/redcap/redcap_v15.5.20/API/index.php Line: 42))
      end
    end

    context "when REDCap sends a full HTML page" do
      let(:json_response) do
        <<~HTML
          <!DOCTYPE html>
          <html>
            <head>
              <style>.red { color: #800000; }</style>
              <script>var app_path_webroot = '/redcap_v15.5.20/';</script>
            </head>
            <body><div class="red">#{"The REDCap API is offline for maintenance. " * 40}</div></body>
          </html>
        HTML
      end

      before do
        allow(JSON).to receive(:load).and_call_original
      end

      it "leaves out scripts and styles, and quotes up to 1000 characters of the text" do
        expect {
          client.json_api_request(options)
        }.to raise_error(REDCap::Client::NonJSONResponseError) { |error|
          expect(error.message).to start_with("REDCap sent an HTML error instead of JSON: The REDCap API is offline for maintenance.")
          expect(error.message).not_to include("color", "app_path_webroot")
          expect(error.message.delete_prefix("REDCap sent an HTML error instead of JSON: ").length).to eq(1000)
          expect(error.message).to end_with("...")
        }
      end
    end
  end

  describe "#cached_json_api_request" do
    let(:options) { {content: "record"} }
    let(:json_response) { '[{"study_id": "001"}]' }
    let(:full_url) { "#{url}?content=record&format=json" }

    before do
      allow(response).to receive(:body).and_return(json_response)
      allow(client).to receive(:base_request).and_return(response)
      allow(JSON).to receive(:load).with(json_response).and_return([{"study_id" => "001"}])
      allow(REDCap::Cache).to receive(:fetch).and_yield.and_return(json_response)
      allow(options).to receive(:to_query).and_return("content=record&format=json")
    end

    it "uses cache and parses JSON response" do
      result = client.cached_json_api_request(options)

      expect(result).to eq([{"study_id" => "001"}])
      expect(REDCap::Cache).to have_received(:fetch).with(full_url)
      expect(JSON).to have_received(:load).with(json_response)
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
