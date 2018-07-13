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
      field_class = kwargs[:as]
      if field_class.is_a?(Symbol)
        field_class = lookup_field_class(field_class.to_s)
      end
      if field = find_field(key, field_class)
        field.value
      else
        super
      end
    end

    def find_field key, field_class=nil
      field = fields.find { |field| field.field_name == key }
      field = field_class.new(self, field.attributes, responses) if field_class
      field
    end

    def fields
      @fields ||= data_dictionary.map do |attributes|
        klass = lookup_field_class(attributes["field_type"])
        klass.new(self, attributes, responses)
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
