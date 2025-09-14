RSpec.describe REDCap::Form::Field do
  let(:attributes) do
    {
      "field_name" => "test_field",
      "field_type" => "text",
      "field_label" => "Test Field",
      "required_field" => "y"
    }
  end
  let(:field) { REDCap::Form::Field.new(attributes) }
  let(:responses) { { "test_field" => "test_value" } }

  describe "#initialize" do
    it "stores attributes" do
      expect(field.attributes).to eq(attributes)
    end

    it "allows setting options and associated_fields" do
      options = { default: "default_value" }
      associated_fields = []

      field = REDCap::Form::Field.new(attributes, options, associated_fields)

      expect(field.options).to eq(options)
      expect(field.associated_fields).to eq(associated_fields)
    end
  end

  describe "attribute accessors" do
    it "provides access to field attributes" do
      expect(field.field_name).to eq("test_field")
      expect(field.field_type).to eq("text")
      expect(field.field_label).to eq("Test Field")
      expect(field.required_field).to eq("y")
    end
  end

  describe "#value" do
    it "returns value from responses hash" do
      expect(field.value(responses)).to eq("test_value")
    end

    it "returns nil when field not in responses" do
      expect(field.value({})).to be_nil
    end
  end

  describe "#method_missing" do
    context "with inquiry methods" do
      it "returns true when field_type matches" do
        expect(field.text?).to be true
        expect(field.radio?).to be false
      end
    end

    context "with non-inquiry methods" do
      it "raises NoMethodError" do
        expect { field.unknown_method }.to raise_error(NoMethodError)
      end
    end
  end
end

RSpec.describe REDCap::Form::Text do
  let(:attributes) { { "field_name" => "name", "field_type" => "text" } }
  let(:field) { REDCap::Form::Text.new(attributes) }
  let(:responses) { { "name" => "John Doe" } }

  describe "#value" do
    it "returns string value from responses" do
      expect(field.value(responses)).to eq("John Doe")
    end
  end
end

RSpec.describe REDCap::Form::Notes do
  let(:attributes) { { "field_name" => "notes", "field_type" => "notes" } }
  let(:field) { REDCap::Form::Notes.new(attributes) }

  describe "#text?" do
    it "returns true" do
      expect(field.text?).to be true
    end
  end
end

RSpec.describe REDCap::Form::File do
  let(:attributes) { { "field_name" => "document", "field_type" => "file" } }
  let(:field) { REDCap::Form::File.new(attributes) }

  describe "#value" do
    it "returns field name when file is present" do
      responses = { "document" => "uploaded_file.pdf" }
      expect(field.value(responses)).to eq("document")
    end

    it "returns nil when file is not present" do
      responses = { "document" => "" }
      expect(field.value(responses)).to be_nil
    end

    it "returns nil when field not in responses" do
      expect(field.value({})).to be_nil
    end
  end
end

RSpec.describe REDCap::Form::Yesno do
  let(:attributes) { { "field_name" => "consent", "field_type" => "yesno" } }
  let(:field) { REDCap::Form::Yesno.new(attributes, {}) }

  describe "#value" do
    it "returns true for '1'" do
      responses = { "consent" => "1" }
      expect(field.value(responses)).to be true
    end

    it "returns false for '0'" do
      responses = { "consent" => "0" }
      expect(field.value(responses)).to be false
    end

    it "returns false for any other value" do
      responses = { "consent" => "2" }
      expect(field.value(responses)).to be false
    end

    context "with default option" do
      let(:field) { REDCap::Form::Yesno.new(attributes, { default: true }) }

      it "returns default when response is empty string" do
        responses = { "consent" => "" }
        expect(field.value(responses)).to be true
      end

      it "does not use default when response has value" do
        responses = { "consent" => "0" }
        expect(field.value(responses)).to be false
      end
    end
  end
end

RSpec.describe REDCap::Form::RadioButtons do
  let(:attributes) do
    {
      "field_name" => "gender",
      "field_type" => "radio",
      "select_choices_or_calculations" => "1,Male | 2,Female | 3,Other"
    }
  end
  let(:field) { REDCap::Form::RadioButtons.new(attributes) }

  describe "#value" do
    it "returns option text for selected key" do
      responses = { "gender" => "1" }
      expect(field.value(responses)).to eq("Male")
    end

    it "returns nil for unmatched key" do
      responses = { "gender" => "99" }
      expect(field.value(responses)).to be_nil
    end
  end

  describe "#options" do
    it "parses select choices into hash" do
      expected = { "1" => "Male", "2" => "Female", "3" => "Other" }
      expect(field.options).to eq(expected)
    end
  end
end

RSpec.describe REDCap::Form::Dropdown do
  let(:attributes) do
    {
      "field_name" => "country",
      "field_type" => "dropdown",
      "select_choices_or_calculations" => "1,USA | 2,Canada | 3,Mexico"
    }
  end
  let(:field) { REDCap::Form::Dropdown.new(attributes) }

  describe "#value" do
    it "returns option text like RadioButtons" do
      responses = { "country" => "2" }
      expect(field.value(responses)).to eq("Canada")
    end
  end
end

RSpec.describe REDCap::Form::Checkboxes do
  let(:attributes) do
    {
      "field_name" => "conditions",
      "field_type" => "checkbox",
      "select_choices_or_calculations" => "1,Diabetes | 2,Hypertension | 3,Heart Disease"
    }
  end
  let(:field) { REDCap::Form::Checkboxes.new(attributes) }

  describe "#value" do
    it "returns array of selected option texts" do
      responses = {
        "conditions___1" => "1",
        "conditions___2" => "0",
        "conditions___3" => "1"
      }
      expect(field.value(responses)).to eq(["Diabetes", "Heart Disease"])
    end

    it "returns empty array when no options selected" do
      responses = {
        "conditions___1" => "0",
        "conditions___2" => "0",
        "conditions___3" => "0"
      }
      expect(field.value(responses)).to eq([])
    end
  end
end

RSpec.describe REDCap::Form::CheckboxesWithOther do
  let(:attributes) do
    {
      "field_name" => "hobbies",
      "field_type" => "checkbox",
      "select_choices_or_calculations" => "1,Reading | 2,Sports | 3,Other"
    }
  end
  let(:associated_field) do
    # Create associated text field that would match branching logic for key "3"
    text_field = REDCap::Form::Text.new({
      "field_name" => "hobbies_other_3",
      "field_type" => "text",
      "branching_logic" => '[hobbies(3)]="1"'
    })
    text_field
  end
  let(:field) { REDCap::Form::CheckboxesWithOther.new(attributes, {}, [associated_field]) }

  describe "#value" do
    it "returns regular options as-is" do
      responses = {
        "hobbies___1" => "1",
        "hobbies___2" => "1",
        "hobbies___3" => "0"
      }
      expect(field.value(responses)).to eq(["Reading", "Sports"])
    end

    it "includes other text when other option is selected" do
      responses = {
        "hobbies___1" => "1",
        "hobbies___3" => "1",
        "hobbies_other_3" => "Custom hobby"
      }
      expect(field.value(responses)).to eq(["Reading", "Other: Custom hobby"])
    end
  end
end

RSpec.describe REDCap::Form::CheckboxesWithRadioButtonsOrOther do
  let(:attributes) do
    {
      "field_name" => "symptoms",
      "field_type" => "checkbox",
      "select_choices_or_calculations" => "1,Headache | 2,Nausea | 3,Other"
    }
  end
  let(:radio_field) do
    REDCap::Form::RadioButtons.new({
      "field_name" => "symptoms_radio_1",
      "field_type" => "radio",
      "field_label" => "Headache severity",
      "select_choices_or_calculations" => "1,Mild | 2,Severe",
      "branching_logic" => '[symptoms(1)]="1"'
    })
  end
  let(:other_text_field) do
    REDCap::Form::Text.new({
      "field_name" => "symptoms_other_3",
      "field_type" => "text",
      "field_label" => "Other symptom",
      "branching_logic" => '[symptoms(3)]="1"'
    })
  end
  let(:field) { REDCap::Form::CheckboxesWithRadioButtonsOrOther.new(attributes, {}, [radio_field, other_text_field]) }

  describe "#value" do
    it "returns hash with checkbox options and their radio/other values" do
      responses = {
        "symptoms___1" => "1",
        "symptoms___2" => "0",
        "symptoms___3" => "1",
        "symptoms_radio_1" => "2",
        "symptoms_other_3" => "Dizziness"
      }

      expect(field.value(responses)).to eq({
        "Headache" => "Severe",
        "Other" => "Dizziness"
      })
    end

    it "handles empty responses" do
      responses = {}
      expect(field.value(responses)).to eq({})
    end
  end
end

RSpec.describe REDCap::Form::CheckboxesWithCheckboxesOrOther do
  let(:attributes) do
    {
      "field_name" => "medications",
      "field_type" => "checkbox",
      "select_choices_or_calculations" => "1,Aspirin | 2,Ibuprofen | 501,Other"
    }
  end
  let(:checkbox_field1) do
    REDCap::Form::Checkboxes.new({
      "field_name" => "med_frequency_1",
      "field_type" => "checkbox",
      "select_choices_or_calculations" => "1,Daily | 2,Weekly",
      "branching_logic" => '[medications(1)]="1"'
    })
  end
  let(:checkbox_field2) do
    REDCap::Form::Checkboxes.new({
      "field_name" => "med_frequency_2",
      "field_type" => "checkbox",
      "select_choices_or_calculations" => "1,Daily | 2,As needed",
      "branching_logic" => '[medications(2)]="1"'
    })
  end
  let(:other_text_field) do
    REDCap::Form::Text.new({
      "field_name" => "medications_other_501",
      "field_type" => "text",
      "branching_logic" => '[medications(501)]="1"'
    })
  end
  let(:field) { REDCap::Form::CheckboxesWithCheckboxesOrOther.new(attributes, {}, [checkbox_field1, checkbox_field2, other_text_field]) }

  describe "#value" do
    it "returns hash with checkbox options and their sub-checkbox values" do
      responses = {
        "medications___1" => "1",
        "medications___2" => "1",
        "med_frequency_1___1" => "1",
        "med_frequency_2___2" => "1"
      }

      expect(field.value(responses)).to eq({
        "Aspirin" => [["Daily"]],
        "Ibuprofen" => [["As needed"]]
      })
    end

    it "handles other option with text field" do
      responses = {
        "medications___1" => "0",
        "medications___501" => "1",
        "medications_other_501" => "Tylenol"
      }

      expect(field.value(responses)).to eq({
        "Other" => ["Tylenol"]
      })
    end
  end
end

