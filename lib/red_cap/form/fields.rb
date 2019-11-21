require "active_support/core_ext/object/blank"

class REDCap
  class Form
    class Field < Struct.new(:attributes, :options, :associated_fields)
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

      def value responses
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
        associated_fields.select do |field|
          field.branching_logic == %{[#{field_name}(#{key})]="1"}
        end
      end
    end

    class Text < Field; end
    class Notes < Text
      def text?
        true
      end
    end
    class Descriptive < Field; end
    class Dropdown < Field; end
    class Sql < Field; end

    class File < Field
      def value responses
        if super.present?
          field_name
        end
      end
    end

    class Yesno < Field
      def value responses
        if options.has_key?(:default) && super == ""
          options[:default]
        else
          super == "1"
        end
      end
    end

    class RadioButtons < Field
      def value responses
        options[super]
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
      def value responses
        selected_options(responses).values
      end

      private

      def selected_options responses
        options.select do |key, value|
          responses["#{field_name}___#{key}"] == "1"
        end
      end
    end

    class CheckboxesWithOther < Checkboxes
      def value responses
        selected_options(responses).map do |key, value|
          if other?(key)
            "#{value}: #{other_text_field(key).value(responses)}"
          else
            value
          end
        end
      end

      def other_text_field key
        associated_fields_for_key(key).find(&:text?)
      end

      def other? key
        other_text_field(key)
      end
    end

    # default "checkbox" implementation
    Checkbox = CheckboxesWithOther

    class CheckboxesWithRadioButtonsOrOther < CheckboxesWithOther
      def value responses
        radio_or_other_values = selected_options(responses).keys.map do |key|
          if other?(key)
            other_text_field(key)&.value(responses)
          else
            radio_field_for(key)&.value(responses)
          end
        end

        Hash[selected_options(responses).values.zip(radio_or_other_values)]
      end

      private

      def radio_field_for key
        associated_fields_for_key(key).find(&:radio?)
      end
    end

    class CheckboxesWithCheckboxesOrOther < CheckboxesWithOther
      def value responses
        left = selected_options(responses).values

        right = selected_options(responses).keys.map do |key|
          checkbox_fields_for(key).map do |field|
            field.value(responses)
          end
        end

        if selected_options.keys.include?("501")
          right[-1] = [other_text_field("501")&.value(responses)]
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
