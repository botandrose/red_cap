class REDCap
  class InstrumentTable < ActiveRecord::Base
    self.table_name = :redcap_instrument_tables

    class_attribute :config
    def self.pulls_from config
      self.config = config.reverse_merge({
        key: :study_id,
        repeating: false,
      })

      config[:fields].each do |field|
        define_method field do
          value = form.send(field)
          value.define_singleton_method :var do
            "#{config[:instrument_name]}.#{field}"
          end
          value
        end
      end
    end

    def self.pull client, filter={}
      filter.reverse_merge!({
        content: "record",
        events: Array(config[:events] || config[:event]).join(","),
        fields: [config[:key]] + config[:fields],
      })

      metadata = client.json_api_request({
        content: "metadata",
        fields: config[:fields],
      }, cache: true)

      client.json_api_request(filter).map do |response|
        if config[:repeating]
          next unless response["redcap_repeat_instrument"] == config[:instrument_name]
          repeat_instance = response["redcap_repeat_instance"]
        end
        record = where({
          instrument_name: config[:instrument_name],
          repeat_instance: repeat_instance,
          event: response.fetch("redcap_event_name"),
          key: response.fetch(config[:key].to_s),
        }).first_or_initialize
        record.update!({
          fields: response,
          metadata: metadata,
        })
        record
      end.compact
    end

    def form
      @form ||= REDCap::Form.new(metadata, fields)
    end
  end
end
