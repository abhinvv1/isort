# Isort

A Ruby gem that automatically sorts and organizes your import statements in Ruby files. You can use it on a file or a complete directory at once.
Checkout here: https://rubygems.org/gems/isort

## Installation

```bash
gem install isort
```

## Usage

### Command Line

#### For file:
```bash
isort --file path/to/your/file.rb
or
isort -f path/to/your/file.rb
```
#### For directory
```bash
isort --directory path/to/your/directory
or
isort -d path/to/your/directory
```

### In Ruby Code

```ruby
require 'isort'

sorter = Isort::FileSorter.new('path/to/your/file.rb')
sorter.sort_and_format_imports
```

## Features

- Sorts import statements correctly as per the norms
- Groups imports by type (require, require_relative, include, extend)
- Preserves code structure and spacing
- Maintains conditional requires
- Respects nested class and module definitions

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/abhinvv1/isort.

## License

The gem is available as open source under the terms of the MIT License.
