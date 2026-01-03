# isort

A Ruby gem that automatically sorts and organizes import statements in Ruby files. Inspired by Python's [isort](https://pycqa.github.io/isort/), it brings the same powerful import organization to Ruby projects.

[![Gem Version](https://badge.fury.io/rb/isort.svg)](https://rubygems.org/gems/isort)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- **Section-based grouping**: Automatically groups imports into stdlib, third-party, first-party, and local sections
- **Alphabetical sorting**: Sorts imports alphabetically within each section
- **Comment preservation**: Keeps inline and leading comments attached to their imports
- **Skip directives**: Skip individual imports or entire files from sorting
- **Safety modes**: Check, diff, and atomic modes to prevent unwanted changes
- **Duplicate removal**: Automatically removes duplicate imports
- **Idempotent**: Running multiple times produces the same result
- **Directory support**: Process single files or entire directories recursively

## Installation

Add to your Gemfile:

```ruby
gem 'isort'
```

Or install directly:

```bash
gem install isort
```

## Quick Start

```bash
# Sort imports in a file
isort path/to/file.rb

# Sort all Ruby files in a directory
isort path/to/directory

# Check if files need sorting (dry-run)
isort --check path/to/file.rb

# Show diff without modifying
isort --diff path/to/file.rb
```

## Usage

### Command Line Interface

```bash
isort [options] [file_or_directory]
```

#### Basic Options

| Option | Description |
|--------|-------------|
| `-f, --file=FILE` | Sort a specific file |
| `-d, --directory=DIR` | Sort all Ruby files in directory recursively |

#### Safety Options

| Option | Description |
|--------|-------------|
| `-c, --check` | Check if files need sorting without modifying. Returns exit code 1 if changes needed. |
| `--diff` | Show unified diff of changes without modifying files |
| `--atomic` | Validate Ruby syntax before and after sorting. Won't save if it would introduce syntax errors. |

#### Output Options

| Option | Description |
|--------|-------------|
| `-q, --quiet` | Suppress all output except errors |
| `--verbose` | Show detailed output |
| `-h, --help` | Show help message |
| `-v, --version` | Show version |

### Examples

```bash
# Sort a single file
isort app/models/user.rb

# Sort with verbose output
isort --verbose lib/

# Check if files are sorted (useful in CI)
isort --check app/

# Preview changes without applying
isort --diff app/models/user.rb

# Safe mode - validates syntax before saving
isort --atomic lib/complex_file.rb
```

### Ruby API

```ruby
require 'isort'

# Sort imports in a file
sorter = Isort::FileSorter.new('path/to/file.rb')
changed = sorter.sort_and_format_imports  # Returns true if file was modified

# Check mode (dry-run)
sorter = Isort::FileSorter.new('path/to/file.rb', check: true)
needs_sorting = sorter.check  # Returns true if file needs sorting

# Diff mode
sorter = Isort::FileSorter.new('path/to/file.rb', diff: true)
diff_output = sorter.diff  # Returns diff string or nil

# Atomic mode (validates syntax)
sorter = Isort::FileSorter.new('path/to/file.rb', atomic: true)
sorter.sort_and_format_imports
```

## Import Sections

isort organizes imports into four sections, separated by blank lines:

| Section | Order | Import Types |
|---------|-------|--------------|
| **stdlib** | 1 | `require` statements for Ruby standard library (json, yaml, csv, etc.) |
| **thirdparty** | 2 | `require` statements for external gems |
| **firstparty** | 3 | `include`, `extend`, `autoload`, `using` statements |
| **localfolder** | 4 | `require_relative` statements |

### Before

```ruby
require_relative 'helper'
require 'yaml'
extend ActiveSupport::Concern
require 'json'
include Enumerable
require_relative 'version'
require 'csv'
```

### After

```ruby
require 'csv'
require 'json'
require 'yaml'

include Enumerable

extend ActiveSupport::Concern

require_relative 'helper'
require_relative 'version'
```

## Skip Directives

### Skip Individual Imports

Add `# isort:skip` to keep an import in its original position:

```ruby
require 'must_load_first' # isort:skip
require 'csv'
require 'json'
```

The `must_load_first` import will remain at the top, while others are sorted below it.

### Skip Entire Files

Add `# isort:skip_file` anywhere in the first 50 lines:

```ruby
# frozen_string_literal: true
# isort:skip_file

require 'special_loader'
require 'another_special'
# This file won't be modified by isort
```

## Supported Import Types

isort recognizes and sorts the following Ruby import statements:

| Statement | Example |
|-----------|---------|
| `require` | `require 'json'` |
| `require_relative` | `require_relative 'helper'` |
| `include` | `include Enumerable` |
| `extend` | `extend ActiveSupport::Concern` |
| `autoload` | `autoload :MyClass, 'my_class'` |
| `using` | `using MyRefinement` |

## CI/CD Integration

Use the `--check` flag in your CI pipeline to ensure imports are sorted:

```yaml
# GitHub Actions example
- name: Check import sorting
  run: |
    gem install isort
    isort --check app/ lib/
```

```bash
# Exit codes
# 0 = All files are sorted correctly
# 1 = Files need sorting or errors occurred
```

## Safety Features

### Atomic Mode

The `--atomic` flag validates Ruby syntax before and after sorting:

```bash
isort --atomic file.rb
```

- Skips files that already have syntax errors
- Won't save changes if sorting would introduce syntax errors
- Provides clear error messages

### Preserves Code Structure

isort only modifies import statements and:

- Preserves shebang lines (`#!/usr/bin/env ruby`)
- Preserves magic comments (`# frozen_string_literal: true`)
- Preserves inline comments on imports
- Preserves leading comments above imports
- Maintains proper indentation
- Handles encoding correctly

## Development

```bash
# Clone the repository
git clone https://github.com/abhinvv1/isort.git
cd isort

# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run robocop lint checks
bundle exec rubocop

# Test locally without installing
bundle exec ruby -Ilib -e "require 'isort'; Isort::CLI.start" -- path/to/file.rb
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/abhinvv1/isort.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Changelog

### v0.2.0

- Complete reimplementation with robust architecture
- Section-based import grouping (stdlib, thirdparty, firstparty, localfolder)
- Added `--check` flag for dry-run mode
- Added `--diff` flag to preview changes
- Added `--atomic` flag for syntax validation
- Added skip directives (`# isort:skip` and `# isort:skip_file`)
- Automatic duplicate removal
- Improved comment handling
- Better detection of imports vs strings containing import keywords

### v0.1.x

- Initial release with basic import sorting
