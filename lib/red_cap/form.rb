require "red_cap/form/fields"
require "active_support/core_ext/string/inflections"

module REDCap
  class Form
    def initialize data_dictionary, responses
      @data_dictionary = data_dictionary
      @responses = responses
    end

    attr_reader :data_dictionary, :responses

    # field accessors
    def method_missing method, *args, **kwargs, &block
      key = method.to_s
      options = kwargs.dup
      field_class = options.delete(:as)
      if field_class.is_a?(Symbol)
        field_class = lookup_field_class(field_class.to_s)
      end
      if field = find_field(key, field_class, options)
        field.value(responses)
      else
        super
      end
    end

    def find_field key, field_class, options
      field = fields.find { |field| field.field_name == key }
      field = field_class.new(field.attributes) if field_class
      field.options = options
      field.associated_fields = fields.select do |field|
        field.branching_logic =~ /^\[#{field.field_name}\(.+\)\]="1"$/
      end
      field
    end

    def fields
      @fields ||= data_dictionary.map do |attributes|
        klass = lookup_field_class(attributes["field_type"])
        klass.new(attributes)
      end
    end

    private

    def lookup_field_class field_type
      self.class.const_get field_type.camelize, false
    rescue NameError
      puts "Unimplemented field type: #{field_type}. Falling back to Text."
      Text
    end
  end
end
