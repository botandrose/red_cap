RSpec.describe REDCap do
  let(:url) { "https://redcap.example.com/api/" }
  let(:token) { "test_token_123" }
  let(:client) { instance_double(REDCap::Client) }

  before do
    REDCap.url = nil
    REDCap.token = nil
    REDCap.per_page = nil
    REDCap.cache = nil
  end

  describe "VERSION" do
    it "has a version number" do
      expect(REDCap::VERSION).not_to be nil
      expect(REDCap::VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end

  describe ".configure" do
    it "allows configuration via block" do
      REDCap.configure do |config|
        config.url = url
        config.token = token
        config.per_page = 50
        config.cache = true
      end

      expect(REDCap.url).to eq(url)
      expect(REDCap.token).to eq(token)
      expect(REDCap.per_page).to eq(50)
      expect(REDCap.cache).to be true
    end
  end

  describe ".per_page" do
    it "defaults to 100" do
      expect(REDCap.per_page).to eq(100)
    end

    it "can be overridden" do
      REDCap.per_page = 250
      expect(REDCap.per_page).to eq(250)
    end
  end

  describe "#initialize" do
    it "uses global configuration by default" do
      REDCap.url = url
      REDCap.token = token
      REDCap.per_page = 50

      redcap = REDCap.new
      expect(redcap.url).to eq(url)
      expect(redcap.token).to eq(token)
      expect(redcap.per_page).to eq(50)
    end

    it "accepts instance-specific configuration" do
      redcap = REDCap.new(url: url, token: token, per_page: 75)
      expect(redcap.url).to eq(url)
      expect(redcap.token).to eq(token)
      expect(redcap.per_page).to eq(75)
    end
  end

  describe "#form" do
    let(:metadata) { [{ "field_name" => "test_field", "field_type" => "text" }] }
    let(:form) { instance_double(REDCap::Form) }
    let(:redcap) { REDCap.new(url: url, token: token) }

    before do
      allow(redcap).to receive(:client).and_return(client)
      allow(client).to receive(:metadata).and_return(metadata)
      allow(REDCap::Form).to receive(:new).with(metadata).and_return(form)
    end

    it "creates and memoizes a form instance" do
      expect(redcap.form).to eq(form)
      expect(redcap.form).to eq(form)
      expect(REDCap::Form).to have_received(:new).once
    end
  end

  describe "#find" do
    let(:redcap) { REDCap.new(url: url, token: token) }
    let(:record) { { "study_id" => "001", "name" => "John" } }

    before do
      allow(redcap).to receive(:client).and_return(client)
      allow(client).to receive(:find_record).with("001").and_return(record)
    end

    it "finds a record by study_id" do
      result = redcap.find("001")
      expect(result).to eq(record)
      expect(client).to have_received(:find_record).with("001")
    end
  end

  describe "#all" do
    let(:redcap) { REDCap.new(url: url, token: token) }
    let(:records) { [{ "study_id" => "001" }, { "study_id" => "002" }] }

    before do
      allow(redcap).to receive(:client).and_return(client)
    end

    context "with block" do
      it "yields each record to the block" do
        expect(client).to receive(:records).and_yield(records[0]).and_yield(records[1])

        yielded_records = []
        redcap.all { |record| yielded_records << record }

        expect(yielded_records).to eq(records)
      end
    end

    context "without block" do
      it "returns all records as an array" do
        expect(client).to receive(:records).and_return(records)

        result = redcap.all
        expect(result).to eq(records)
      end
    end
  end

  describe "#where" do
    let(:redcap) { REDCap.new(url: url, token: token) }
    let(:conditions) { { status: 1, age: 25 } }
    let(:filter) { "[status]=1 AND [age]=25" }

    before do
      allow(redcap).to receive(:client).and_return(client)
    end

    it "builds filter string and passes to client" do
      expect(client).to receive(:records).with(filter)

      redcap.where(conditions)
    end

    it "yields records when block given" do
      record = { "study_id" => "001" }
      expect(client).to receive(:records).with(filter).and_yield(record)

      yielded_records = []
      redcap.where(conditions) { |r| yielded_records << r }

      expect(yielded_records).to eq([record])
    end
  end

  describe "#update" do
    let(:redcap) { REDCap.new(url: url, token: token) }
    let(:attributes) { { name: "Jane", age: 30 } }
    let(:expected_record) { { "study_id" => "001", "name" => "Jane", "age" => 30 } }

    before do
      allow(redcap).to receive(:client).and_return(client)
      allow(client).to receive(:save_records)
    end

    it "updates a record with given attributes" do
      redcap.update("001", attributes)

      expect(client).to have_received(:save_records).with([expected_record])
    end
  end

  describe "#delete" do
    let(:redcap) { REDCap.new(url: url, token: token) }

    before do
      allow(redcap).to receive(:client).and_return(client)
      allow(client).to receive(:delete_records)
    end

    it "deletes a record by study_id" do
      redcap.delete("001")

      expect(client).to have_received(:delete_records).with(["001"])
    end
  end

  describe "#client" do
    let(:redcap) { REDCap.new(url: url, token: token, per_page: 50) }

    it "creates and memoizes a client instance" do
      expect(REDCap::Client).to receive(:new).with(url: url, token: token, per_page: 50).and_return(client)

      expect(redcap.client).to eq(client)
      expect(redcap.client).to eq(client)
    end
  end
end
