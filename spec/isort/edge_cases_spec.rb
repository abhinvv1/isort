# frozen_string_literal: true

require "isort"
require "tempfile"
require "fileutils"

RSpec.describe "Isort edge cases" do
  let(:tempfile) { Tempfile.new(["test", ".rb"]) }
  let(:sorter) { Isort::FileSorter.new(tempfile.path) }

  after do
    tempfile.close
    tempfile.unlink
  end

  describe "shebang and magic comments" do
    it "preserves shebang on first line" do
      content = <<~RUBY
        #!/usr/bin/env ruby
        require 'yaml'
        require 'json'
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      lines = result.lines
      expect(lines.first).to eq("#!/usr/bin/env ruby\n")
      expect(result).to include("require 'json'")
      expect(result).to include("require 'yaml'")
    end

    it "preserves frozen_string_literal magic comment" do
      content = <<~RUBY
        # frozen_string_literal: true
        require 'yaml'
        require 'json'
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      lines = result.lines
      expect(lines.first).to eq("# frozen_string_literal: true\n")
    end

    it "preserves both shebang and magic comment in correct order" do
      content = <<~RUBY
        #!/usr/bin/env ruby
        # frozen_string_literal: true
        # encoding: utf-8
        require 'yaml'
        require 'json'
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      lines = result.lines
      expect(lines[0]).to eq("#!/usr/bin/env ruby\n")
      expect(lines[1]).to include("frozen_string_literal")
    end
  end

  describe "inline comments" do
    it "preserves inline comments on imports" do
      content = <<~RUBY
        require 'json' # for parsing JSON
        require 'csv'  # handles CSV files
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      expect(result).to include("# for parsing JSON")
      expect(result).to include("# handles CSV files")
    end

    it "sorts imports while keeping inline comments attached" do
      content = <<~RUBY
        require 'yaml' # YAML parser
        require 'json' # JSON parser
        require 'csv'  # CSV parser
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      # csv should come before json should come before yaml
      csv_pos = result.index("require 'csv'")
      json_pos = result.index("require 'json'")
      yaml_pos = result.index("require 'yaml'")
      expect(csv_pos).to be < json_pos
      expect(json_pos).to be < yaml_pos
    end
  end

  describe "leading comments" do
    it "keeps leading comments with their imports" do
      content = <<~RUBY
        # This requires yaml for config
        require 'yaml'
        # JSON is for API responses
        require 'json'
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      # Comments should stay with their respective imports
      json_comment_pos = result.index("# JSON is for API responses")
      json_require_pos = result.index("require 'json'")
      yaml_comment_pos = result.index("# This requires yaml for config")
      yaml_require_pos = result.index("require 'yaml'")

      expect(json_comment_pos).to be < json_require_pos
      expect(yaml_comment_pos).to be < yaml_require_pos
    end

    it "preserves multi-line leading comments" do
      content = <<~RUBY
        # First line of comment
        # Second line of comment
        require 'json'
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      expect(result).to include("# First line of comment")
      expect(result).to include("# Second line of comment")
    end
  end

  describe "duplicate imports" do
    it "removes duplicate require statements" do
      content = <<~RUBY
        require 'json'
        require 'yaml'
        require 'json'
        require 'csv'
        require 'yaml'
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      expect(result.scan("require 'json'").count).to eq(1)
      expect(result.scan("require 'yaml'").count).to eq(1)
      expect(result.scan("require 'csv'").count).to eq(1)
    end

    it "removes duplicate require_relative statements" do
      content = <<~RUBY
        require_relative 'helper'
        require_relative 'utils'
        require_relative 'helper'
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      expect(result.scan("require_relative 'helper'").count).to eq(1)
    end

    it "removes duplicate include statements" do
      content = <<~RUBY
        include Comparable
        include Enumerable
        include Comparable
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      expect(result.scan("include Comparable").count).to eq(1)
    end
  end

  describe "blank line handling" do
    it "adds single blank line between different sections and import types" do
      content = <<~RUBY
        require 'json'
        require_relative 'helper'
        include MyModule
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      # With section-based grouping:
      # 1. stdlib requires (json)
      # 2. firstparty includes (MyModule - not a stdlib constant)
      # 3. localfolder require_relatives (helper)
      expect(result).to eq(<<~RUBY)
        require 'json'

        include MyModule

        require_relative 'helper'
      RUBY
    end

    it "normalizes multiple blank lines between groups to single blank" do
      content = <<~RUBY
        require 'json'


        require_relative 'helper'
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      # Should have exactly one blank line between groups, not two
      expect(result).to eq(<<~RUBY)
        require 'json'

        require_relative 'helper'
      RUBY
    end
  end

  describe "nested imports" do
    it "sorts imports inside class definitions" do
      content = <<~RUBY
        class MyClass
          include Comparable
          include Enumerable
          extend ActiveModel
        end
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      # Imports inside class should be sorted
      comparable_pos = result.index("include Comparable")
      enumerable_pos = result.index("include Enumerable")
      expect(comparable_pos).to be < enumerable_pos
    end

    it "sorts imports inside module definitions" do
      content = <<~RUBY
        module MyModule
          require_relative 'z_file'
          require_relative 'a_file'
        end
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      a_pos = result.index("require_relative 'a_file'")
      z_pos = result.index("require_relative 'z_file'")
      expect(a_pos).to be < z_pos
    end
  end

  describe "conditional imports" do
    it "preserves conditional import structure" do
      content = <<~RUBY
        if defined?(Rails)
          require 'rails/engine'
        end
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      expect(result).to include("if defined?(Rails)")
      expect(result).to include("require 'rails/engine'")
      expect(result).to include("end")
    end

    it "sorts top-level imports before conditional blocks" do
      content = <<~RUBY
        require 'json'
        if defined?(Rails)
          require 'rails/engine'
        end
        require 'csv'
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      # Top-level requires should be sorted within their blocks
      expect(result).to include("require 'json'")
      expect(result).to include("require 'csv'")
    end
  end

  describe "files with no imports" do
    it "does not modify files with only code" do
      content = <<~RUBY
        def hello
          puts "Hello, World!"
        end

        hello
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      expect(File.read(tempfile.path)).to eq(content)
    end

    it "does not modify files with only comments" do
      content = <<~RUBY
        # This is a comment
        # Another comment
        # More comments
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      expect(File.read(tempfile.path)).to eq(content)
    end
  end

  describe "import types" do
    it "sorts all six import types correctly with section-based grouping" do
      content = <<~RUBY
        using SomeRefinement
        autoload :Foo, 'foo'
        extend Extendable
        include Includable
        require_relative 'local'
        require 'json'
        require 'active_support'
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)

      # With section-based grouping, order is:
      # 1. stdlib requires (json is stdlib)
      # 2. thirdparty requires (active_support is a gem)
      # 3. firstparty (include, extend, autoload, using - project-specific)
      # 4. localfolder (require_relative)
      #
      # Within firstparty, order by type: include, extend, autoload, using
      stdlib_require_pos = result.index("require 'json'")
      thirdparty_require_pos = result.index("require 'active_support'")
      include_pos = result.index("include Includable")
      extend_pos = result.index("extend Extendable")
      autoload_pos = result.index("autoload :Foo")
      using_pos = result.index("using SomeRefinement")
      relative_pos = result.index("require_relative 'local'")

      # stdlib before thirdparty
      expect(stdlib_require_pos).to be < thirdparty_require_pos
      # thirdparty before firstparty
      expect(thirdparty_require_pos).to be < include_pos
      # within firstparty, sorted by type: include < extend < autoload < using
      expect(include_pos).to be < extend_pos
      expect(extend_pos).to be < autoload_pos
      expect(autoload_pos).to be < using_pos
      # localfolder (require_relative) comes last
      expect(using_pos).to be < relative_pos
    end
  end

  describe "special require patterns" do
    it "handles require with double quotes" do
      content = <<~RUBY
        require "json"
        require "csv"
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      expect(result.index('require "csv"')).to be < result.index('require "json"')
    end

    it "handles require with parentheses" do
      content = <<~RUBY
        require('json')
        require('csv')
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      expect(result.index("require('csv')")).to be < result.index("require('json')")
    end

    it "handles mixed quote styles" do
      content = <<~RUBY
        require 'json'
        require "csv"
        require 'yaml'
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      # Should sort alphabetically regardless of quote style
      csv_pos = result.index('require "csv"')
      json_pos = result.index("require 'json'")
      yaml_pos = result.index("require 'yaml'")
      expect(csv_pos).to be < json_pos
      expect(json_pos).to be < yaml_pos
    end
  end

  describe "idempotency" do
    it "produces same output when run multiple times" do
      content = <<~RUBY
        require 'yaml'
        require 'json'
        require_relative 'b'
        require_relative 'a'
        include B
        include A
      RUBY

      tempfile.write(content)
      tempfile.flush

      # Run first time
      sorter.sort_and_format_imports
      first_result = File.read(tempfile.path)

      # Run second time
      sorter.sort_and_format_imports
      second_result = File.read(tempfile.path)

      # Run third time
      sorter.sort_and_format_imports
      third_result = File.read(tempfile.path)

      expect(first_result).to eq(second_result)
      expect(second_result).to eq(third_result)
    end
  end

  describe "code preservation" do
    it "preserves code after imports" do
      content = <<~RUBY
        require 'json'
        require 'csv'

        class MyClass
          def initialize
            @data = {}
          end
        end
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      expect(result).to include("class MyClass")
      expect(result).to include("def initialize")
      expect(result).to include("@data = {}")
    end

    it "preserves heredocs" do
      content = <<~RUBY
        require 'json'

        SQL = <<~SQL
          SELECT * FROM users
          WHERE require = 'not an import'
        SQL
      RUBY

      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      expect(result).to include("require = 'not an import'")
    end
  end

  describe "error handling" do
    it "raises Errno::ENOENT for non-existent file" do
      sorter = Isort::FileSorter.new("definitely_not_a_real_file.rb")
      expect { sorter.sort_and_format_imports }.to raise_error(Errno::ENOENT)
    end

    it "raises Encoding::CompatibilityError for invalid UTF-8" do
      File.binwrite(tempfile.path, "require 'json'\xFF\xFE")
      expect { sorter.sort_and_format_imports }.to raise_error(Encoding::CompatibilityError)
    end
  end

  describe "trailing newline" do
    it "ensures file ends with single newline" do
      content = "require 'json'\nrequire 'csv'"
      tempfile.write(content)
      tempfile.flush
      sorter.sort_and_format_imports

      result = File.read(tempfile.path)
      expect(result).to end_with("\n")
      expect(result).not_to end_with("\n\n")
    end
  end
end
