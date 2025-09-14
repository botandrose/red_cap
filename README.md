# REDCap

![CI](https://github.com/botandrose/red_cap/workflows/CI/badge.svg)
![Coverage](https://codecov.io/gh/botandrose/red_cap/branch/master/graph/badge.svg)

A Ruby client library for connecting to REDCap (Research Electronic Data Capture) and parsing forms and data. REDCap is a secure web application for building and managing online surveys and databases, particularly for research studies.

## Features

- **REDCap API Integration**: Full client for REDCap's API endpoints
- **Form Parsing**: Dynamic form handling with Ruby-friendly field access
- **Field Type Support**: Comprehensive support for REDCap field types (text, radio buttons, checkboxes, dropdowns, etc.)
- **Caching**: Optional response caching for improved performance
- **Batch Operations**: Efficient handling of large datasets with pagination
- **File Handling**: Support for file uploads and downloads

## Configuration

Configure the gem globally:

```ruby
REDCap.configure do |config|
  config.url = "https://your-redcap-instance.org/api/"
  config.token = "your_api_token_here"
  config.per_page = 100  # optional, defaults to 100
  config.cache = true    # optional, defaults to nil (no caching)
end
```

Or create instances with specific configurations:

```ruby
client = REDCap.new(
  url: "https://your-redcap-instance.org/api/",
  token: "your_api_token_here",
  per_page: 50
)
```

## Usage

### Basic Data Operations

```ruby
# Find a specific record
record = client.find("study_id_001")

# Get all records (with block for memory efficiency)
client.all do |record|
  puts record["study_id"]
end

# Get all records as array
records = client.all

# Filter records
client.where(status: 1, age: 25) do |record|
  puts record["name"]
end

# Update a record
client.update("study_id_001", { name: "John Doe", age: 30 })

# Delete a record
client.delete("study_id_001")
```

### Working with Forms

```ruby
# Access the form structure
form = client.form

# Access field values with dynamic methods
form.responses = record_data
puts form.participant_name  # accesses field "participant_name"
puts form.age               # accesses field "age"
puts form.consent_date      # accesses field "consent_date"

# Check field types
field = form.fields.find { |f| f.field_name == "gender" }
puts field.radio?          # true if radio button field
puts field.checkbox?       # true if checkbox field
puts field.field_type      # "radio", "checkbox", etc.
```

### Field Types

The gem supports various REDCap field types with appropriate Ruby representations:

- **Text fields**: Return string values
- **Yes/No fields**: Return boolean values
- **Radio buttons**: Return selected option text
- **Checkboxes**: Return array of selected options
- **Dropdowns**: Return selected option text
- **Files**: Return field name if file exists

### Advanced Field Access

```ruby
# Override field type interpretation
form.my_field(as: :radio_buttons)

# Access with options
form.checkbox_field(default: false)
```

### File Handling

```ruby
# Download a file
file = client.client.file("record_id", "file_field_name")
puts file.filename
puts file.type
# file.data contains the file content
```

### Caching

Enable caching to improve performance for repeated API calls:

```ruby
REDCap.configure do |config|
  config.cache = true
end

# Clear cache when needed
REDCap::Cache.clear
```

## Field Types Reference

| REDCap Type   | Ruby Class          | Return Value               |
| ------------- | ------------------- | -------------------------- |
| text          | Text                | String                     |
| notes         | Notes               | String                     |
| yesno         | Yesno               | Boolean                    |
| radio         | RadioButtons        | String (selected option)   |
| dropdown      | Dropdown            | String (selected option)   |
| checkbox      | CheckboxesWithOther | Array of strings           |
| file          | File                | String (field name) or nil |

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/botandrose/red_cap.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
