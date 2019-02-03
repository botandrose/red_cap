require "active_support/core_ext/object/blank"

module REDCap
  class Form
    class Field < Struct.new(:form, :attributes, :responses, :options)
      KEYS = [
        :field_name,
        :form_name,
        :section_header,
        :field_type,
        :field_label,
        :select_choices_or_calculations,
        :field_note,
        :text_validation_type_or_show_slider_number,
        :text_validation_min,
        :text_validation_max,
        :identifier,
        :branching_logic,
        :required_field,
        :custom_alignment,
        :question_number,
        :matrix_group_name,
        :matrix_ranking,
        :field_annotation,
      ].each do |key|
        define_method key do
          attributes[key.to_s]
        end
      end

      def value
        responses[field_name]
      end

      # field type inquiry methods
      def method_missing method, *args, **kwargs, &block
        if method.to_s.ends_with?("?")
          field_type == method.to_s.chomp("?")
        else
          super
        end
      end

      private

      def associated_fields_for_key key
        form.fields.select do |field|
          field.branching_logic == %{[#{field_name}(#{key})]="1"}
        end
      end
    end

    class Text < Field; end
    class Notes < Field; end
    class Descriptive < Field; end
    class Dropdown < Field; end
    class Sql < Field; end

    class File < Field
      def value
        if responses[field_name].present?
          field_name
        end
      end
    end

    class Yesno < Field
      def value
        if options.has_key?(:default) && super == ""
          options[:default]
        else
          super == "1"
        end
      end
    end

    class RadioButtons < Field
      def value
        options[responses[field_name]]
      end

      def options
        select_choices_or_calculations
          .split(/\s*\|\s*/)
          .reduce({}) do |options, pair|
            _, key, value = *pair.match(/\A(\d+),(.+)\z/)
            options.merge key => value
          end
      end
    end

    # default "radio" implementation
    Radio = RadioButtons

    class Checkboxes < RadioButtons
      def value
        selected_options.values
      end

      private

      def selected_options
        options.select do |key, value|
          responses["#{field_name}___#{key}"] == "1"
        end
      end
    end

    class CheckboxesWithOther < Checkboxes
      def value
        selected_options.map do |key, value|
          if key == "501" # Other
            "#{value}: #{other_text_field&.value}"
          else
            value
          end
        end
      end

      def other_text_field
        associated_fields_for_key("501").find(&:text?)
      end
    end

    # default "checkbox" implementation
    Checkbox = CheckboxesWithOther

    class CheckboxesWithRadioButtonsOrOther < CheckboxesWithOther
      def value
        radio_values = selected_options.keys.map do |key|
          radio_field_for(key).value
        end

        Hash[super.zip(radio_values)]
      end

      private

      def radio_field_for key
        associated_fields_for_key(key).find(&:radio?)
      end
    end

    class CheckboxesWithCheckboxesOrOther < CheckboxesWithOther
      def value
        left = selected_options.values

        right = selected_options.keys.map do |key|
          checkbox_fields_for(key).map(&:value)
        end

        if selected_options.keys.include?("501")
          right[-1] = [other_text_field&.value]
        end

        Hash[left.zip(right)]
      end

      private

      def checkbox_fields_for key
        associated_fields_for_key(key).select(&:checkbox?)
      end
    end
  end
end
