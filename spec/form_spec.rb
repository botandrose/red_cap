RSpec.describe REDCap::Form do
  let(:data_dictionary) do
    [
      {
        "field_name" => "study_id",
        "field_type" => "text",
        "field_label" => "Study ID"
      },
      {
        "field_name" => "name",
        "field_type" => "text",
        "field_label" => "Participant Name"
      },
      {
        "field_name" => "consent",
        "field_type" => "yesno",
        "field_label" => "Consent Given"
      },
      {
        "field_name" => "gender",
        "field_type" => "radio",
        "field_label" => "Gender",
        "select_choices_or_calculations" => "1,Male | 2,Female | 3,Other"
      },
      {
        "field_name" => "conditions",
        "field_type" => "checkbox",
        "field_label" => "Medical Conditions",
        "select_choices_or_calculations" => "1,Diabetes | 2,Hypertension | 3,Other"
      }
    ]
  end
  let(:responses) do
    {
      "study_id" => "001",
      "name" => "John Doe",
      "consent" => "1",
      "gender" => "1",
      "conditions___1" => "1",
      "conditions___2" => "0",
      "conditions___3" => "1"
    }
  end
  let(:form) { REDCap::Form.new(data_dictionary, responses) }

  describe "#initialize" do
    it "accepts data dictionary and responses" do
      form = REDCap::Form.new(data_dictionary, responses)

      expect(form.data_dictionary).to eq(data_dictionary)
      expect(form.responses).to eq(responses)
    end

    it "accepts data dictionary without responses" do
      form = REDCap::Form.new(data_dictionary)

      expect(form.data_dictionary).to eq(data_dictionary)
      expect(form.responses).to be_nil
    end
  end

  describe "#method_missing" do
    context "when field exists" do
      it "returns field value for text fields" do
        expect(form.study_id).to eq("001")
        expect(form.name).to eq("John Doe")
      end

      it "returns field value for yesno fields" do
        expect(form.consent).to be true
      end

      it "returns field value for radio fields" do
        expect(form.gender).to eq("Male")
      end

      it "returns field value for checkbox fields" do
        expect(form.conditions).to eq(["Diabetes", "Other"])
      end
    end

    context "when field does not exist" do
      it "raises NoMethodError" do
        expect { form.nonexistent_field }.to raise_error(NoMethodError)
      end

      it "calls super when field is not found" do
        # Use a form with minimal data dictionary to avoid the nil options issue
        minimal_form = REDCap::Form.new([
          {
            "field_name" => "test_field",
            "field_type" => "text"
          }
        ])

        # Call a method that doesn't match any field to trigger super
        expect { minimal_form.unknown_field_name }.to raise_error(NoMethodError, /undefined method `unknown_field_name'/)
      end
    end

    context "with field_class override" do
      it "creates field with specified class" do
        allow(form).to receive(:find_field).and_call_original

        form.gender(as: :radio_buttons)

        expect(form).to have_received(:find_field).with("gender", REDCap::Form::RadioButtons, {})
      end

      it "accepts symbol for field class" do
        result = form.gender(as: :radio_buttons)
        expect(result).to eq("Male")
      end
    end

    context "with options" do
      let(:yesno_field) { instance_double(REDCap::Form::Yesno) }

      before do
        allow(form).to receive(:find_field).and_return(yesno_field)
        allow(yesno_field).to receive(:value).and_return(false)
      end

      it "passes options to field" do
        form.consent(default: false)

        expect(form).to have_received(:find_field).with("consent", nil, { default: false })
      end
    end
  end

  describe "#find_field" do
    let(:field) { form.fields.find { |f| f.field_name == "gender" } }
    let(:options) { { default: "Unknown" } }

    it "finds field by name" do
      result = form.find_field("gender", nil, {})
      expect(result.field_name).to eq("gender")
      expect(result).to be_a(REDCap::Form::RadioButtons)
    end

    it "creates new instance with field_class when provided" do
      result = form.find_field("gender", REDCap::Form::Text, {})
      expect(result).to be_a(REDCap::Form::Text)
      expect(result.field_name).to eq("gender")
    end

    it "sets options attribute on field" do
      result = form.find_field("study_id", REDCap::Form::Text, options)
      expect(result.options).to eq(options)
    end
  end

  describe "#fields" do
    it "creates field instances from data dictionary" do
      fields = form.fields

      expect(fields.length).to eq(5)
      expect(fields[0]).to be_a(REDCap::Form::Text)
      expect(fields[0].field_name).to eq("study_id")
      expect(fields[2]).to be_a(REDCap::Form::Yesno)
      expect(fields[2].field_name).to eq("consent")
      expect(fields[3]).to be_a(REDCap::Form::RadioButtons)
      expect(fields[3].field_name).to eq("gender")
    end

    it "memoizes field instances" do
      expect(form.fields).to be(form.fields)
    end

    it "sets up associated fields based on branching logic" do
      data_with_branching = data_dictionary + [
        {
          "field_name" => "other_specify",
          "field_type" => "text",
          "branching_logic" => "[gender(3)]=\"1\""
        }
      ]
      form_with_branching = REDCap::Form.new(data_with_branching)

      fields = form_with_branching.fields
      gender_field = fields.find { |f| f.field_name == "gender" }
      other_field = fields.find { |f| f.field_name == "other_specify" }

      expect(gender_field.associated_fields).to include(other_field)
    end

    context "with unknown field type" do
      let(:data_with_unknown) do
        data_dictionary + [{
          "field_name" => "unknown_field",
          "field_type" => "unknown_type",
          "field_label" => "Unknown Field"
        }]
      end

      it "falls back to Text field type" do
        form_with_unknown = REDCap::Form.new(data_with_unknown)
        fields = form_with_unknown.fields
        unknown_field = fields.find { |f| f.field_name == "unknown_field" }

        expect(unknown_field).to be_a(REDCap::Form::Text)
      end

      it "prints warning message" do
        expect { REDCap::Form.new(data_with_unknown).fields }.to output(
          "Unimplemented field type: unknown_type. Falling back to Text.\n"
        ).to_stdout
      end
    end
  end

  describe "lookup_field_class" do
    it "finds field class by name" do
      field_class = form.send(:lookup_field_class, "text")
      expect(field_class).to eq(REDCap::Form::Text)
    end

    it "finds field class with camelized name" do
      field_class = form.send(:lookup_field_class, "radio_buttons")
      expect(field_class).to eq(REDCap::Form::RadioButtons)
    end

    it "falls back to Text for unknown types" do
      expect {
        field_class = form.send(:lookup_field_class, "nonexistent")
        expect(field_class).to eq(REDCap::Form::Text)
      }.to output(/Unimplemented field type: nonexistent/).to_stdout
    end
  end
end