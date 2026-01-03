# frozen_string_literal: true

require "isort"
require "fileutils"

RSpec.describe Isort::FileSorter do
  let(:file_path) { "spec/fixtures/sample.rb" }
  let(:file_sorter) { described_class.new(file_path) }

  before do
    FileUtils.mkdir_p("spec/fixtures")
  end

  after do
    File.delete(file_path) if File.exist?(file_path)
  end

  describe "#sort_and_format_imports" do
    context "with basic import sorting" do
      before do
        File.write(file_path, <<~RUBY)
          require 'json'
          require_relative 'b_file'
          require 'csv'
          include SomeModule
          require_relative 'a_file'
        RUBY
      end

      it "sorts imports alphabetically and groups by section then type" do
        file_sorter.sort_and_format_imports

        # With section-based grouping:
        # 1. stdlib requires (csv, json)
        # 2. firstparty includes (SomeModule)
        # 3. localfolder require_relatives (a_file, b_file)
        expect(File.read(file_path)).to eq(<<~RUBY)
          require 'csv'
          require 'json'

          include SomeModule

          require_relative 'a_file'
          require_relative 'b_file'
        RUBY
      end

      it "maintains file content when imports are already sorted" do
        sorted_content = <<~RUBY
          require 'csv'
          require 'json'

          include SomeModule

          require_relative 'a_file'
          require_relative 'b_file'
        RUBY

        File.write(file_path, sorted_content)
        file_sorter.sort_and_format_imports

        expect(File.read(file_path)).to eq(sorted_content)
      end

      it "handles empty files" do
        File.write(file_path, "")
        file_sorter.sort_and_format_imports

        expect(File.read(file_path)).to eq("")
      end

      it "handles files with only comments" do
        content = <<~RUBY
          # This is a comment
          # Another comment
        RUBY

        File.write(file_path, content)
        file_sorter.sort_and_format_imports

        expect(File.read(file_path)).to eq(content)
      end

      it "preserves inline comments" do
        File.write(file_path, <<~RUBY)
          require 'json' # JSON parser
          require 'csv' # CSV handler
          require_relative 'b_file' # Custom file
          include SomeModule # Include module
          require_relative 'a_file' # Another file
        RUBY

        file_sorter.sort_and_format_imports

        # Section-based order: stdlib, firstparty, localfolder
        expect(File.read(file_path)).to eq(<<~RUBY)
          require 'csv' # CSV handler
          require 'json' # JSON parser

          include SomeModule # Include module

          require_relative 'a_file' # Another file
          require_relative 'b_file' # Custom file
        RUBY
      end
    end

    context "when the file contains unsorted imports" do
      before do
        File.write(file_path, <<~RUBY)
          require 'json'
          require 'yaml'
          require 'csv'
        RUBY
      end

      it "sorts the imports alphabetically" do
        sorter = described_class.new(file_path)
        sorter.sort_and_format_imports

        expect(File.read(file_path)).to eq(<<~RUBY)
          require 'csv'
          require 'json'
          require 'yaml'
        RUBY
      end
    end

    context "when the file contains no imports" do
      before do
        File.write(file_path, "puts 'Hello, world!'")
      end

      it "does not modify the file" do
        sorter = described_class.new(file_path)
        sorter.sort_and_format_imports

        expect(File.read(file_path)).to eq("puts 'Hello, world!'")
      end
    end

    context "when the file is empty" do
      before do
        File.write(file_path, "")
      end

      it "does not raise an error or modify the file" do
        sorter = described_class.new(file_path)
        sorter.sort_and_format_imports

        expect(File.read(file_path)).to eq("")
      end
    end

    context "when the file has non-import lines mixed with imports" do
      before do
        File.write(file_path, <<~RUBY)
          require 'json'
          puts 'This is a test.'
          require_relative 'a_file'
          require 'csv'
        RUBY
      end

      it "sorts imports within each contiguous block separately" do
        sorter = described_class.new(file_path)
        sorter.sort_and_format_imports

        # Code line breaks the import block, so imports before and after
        # are treated as separate blocks
        expect(File.read(file_path)).to eq(<<~RUBY)
          require 'json'
          puts 'This is a test.'
          require 'csv'

          require_relative 'a_file'
        RUBY
      end
    end
  end

  describe "#sort_and_format_imports" do
    context "with advanced formatting" do
      before do
        File.write(file_path, <<~RUBY)
          require 'json'
          include SomeModule
          require_relative 'b_file'
          require 'csv'
          extend AnotherModule
          autoload :CSV, 'csv'
          using SomeRefinement
          require_relative 'a_file'
        RUBY
      end

      it "sorts and formats imports with section-based grouping" do
        file_sorter.sort_and_format_imports

        # Section-based order:
        # 1. stdlib (csv, json)
        # 2. firstparty (include, extend, autoload, using)
        # 3. localfolder (require_relative)
        expect(File.read(file_path)).to eq(<<~RUBY)
          require 'csv'
          require 'json'

          include SomeModule

          extend AnotherModule

          autoload :CSV, 'csv'

          using SomeRefinement

          require_relative 'a_file'
          require_relative 'b_file'
        RUBY
      end

      it "handles mixed case requires within same section" do
        File.write(file_path, <<~RUBY)
          require 'JSON'
          require 'Csv'
          require 'stringio'
        RUBY

        file_sorter.sort_and_format_imports

        # stringio is stdlib, JSON and Csv are thirdparty (not lowercase stdlib names)
        # Alphabetically sorted within each section
        expect(File.read(file_path)).to eq(<<~RUBY)
          require 'stringio'

          require 'Csv'
          require 'JSON'
        RUBY
      end

      it "handles multiple includes of the same type" do
        File.write(file_path, <<~RUBY)
          include ModuleB
          require 'json'
          include ModuleA
          include ModuleC
        RUBY

        file_sorter.sort_and_format_imports

        expect(File.read(file_path)).to eq(<<~RUBY)
          require 'json'

          include ModuleA
          include ModuleB
          include ModuleC
        RUBY
      end
    end
  end

  describe "#sort_and_format_imports" do
    it "preserves nested extends inside classes" do
      File.write(file_path, <<~RUBY)
        require 'json'


        include ModuleA

        class MyClass
          extend ModuleB
        end
      RUBY

      file_sorter.sort_and_format_imports

      expect(File.read(file_path)).to eq(<<~RUBY)
        require 'json'

        include ModuleA

        class MyClass
          extend ModuleB
        end
      RUBY
    end

    it "preserves conditional imports structure" do
      File.write(file_path, <<~RUBY)
        require 'csv'
        if RUBY_VERSION >= '2.7'
          require 'json'
        else
          require 'oj'
        end
      RUBY

      file_sorter.sort_and_format_imports

      # Conditional imports stay in place, top-level sorted
      expect(File.read(file_path)).to eq(<<~RUBY)
        require 'csv'
        if RUBY_VERSION >= '2.7'
          require 'json'
        else
          require 'oj'
        end
      RUBY
    end

    it "preserves nested modules and their imports" do
      File.write(file_path, <<~RUBY)
        require 'json'
        require 'csv'

        module OuterModule
          include ModuleA

          class InnerClass
            extend ModuleB
          end
        end
      RUBY

      file_sorter.sort_and_format_imports

      expect(File.read(file_path)).to eq(<<~RUBY)
        require 'csv'
        require 'json'

        module OuterModule
          include ModuleA

          class InnerClass
            extend ModuleB
          end
        end
      RUBY
    end
  end

  context "when the file contains various types of imports" do
    before do
      File.write(file_path, <<~RUBY)
        include SomeModule
        require 'json'
        require_relative 'b_file'
        autoload :CSV, 'csv'
        using SomeRefinement
        extend AnotherModule
        require 'csv'
        require_relative 'a_file'
      RUBY
    end

    it "groups, sorts, and formats the imports correctly with section-based grouping" do
      sorter = described_class.new(file_path)
      sorter.sort_and_format_imports

      # Section-based order:
      # 1. stdlib (csv, json)
      # 2. firstparty (include, extend, autoload, using - sorted by type then alpha)
      # 3. localfolder (require_relative)
      expect(File.read(file_path)).to eq(<<~RUBY)
        require 'csv'
        require 'json'

        include SomeModule

        extend AnotherModule

        autoload :CSV, 'csv'

        using SomeRefinement

        require_relative 'a_file'
        require_relative 'b_file'
      RUBY
    end
  end

  context "when the file contains only non-import lines" do
    before do
      File.write(file_path, <<~RUBY)
        puts 'Hello, world!'
        def hello; puts 'Hi'; end
      RUBY
    end

    it "does not modify the file" do
      sorter = described_class.new(file_path)
      sorter.sort_and_format_imports

      expect(File.read(file_path)).to eq(<<~RUBY)
        puts 'Hello, world!'
        def hello; puts 'Hi'; end
      RUBY
    end
  end

  context "when the file contains blank lines and comments" do
    before do
      File.write(file_path, <<~RUBY)
        # This is a comment
        require 'yaml'

        require 'json'
        # Another comment
        require_relative 'b_file'
      RUBY
    end

    it "preserves comments while sorting imports" do
      sorter = described_class.new(file_path)
      sorter.sort_and_format_imports

      expect(File.read(file_path)).to eq(<<~RUBY)
        require 'json'
        # This is a comment
        require 'yaml'

        # Another comment
        require_relative 'b_file'
      RUBY
    end
  end

  context "when the file has load statements mixed with imports" do
    before do
      File.write(file_path, <<~RUBY)
        load 'some_file'
        require 'json'
      RUBY
    end

    it "treats load as non-import code" do
      sorter = described_class.new(file_path)
      sorter.sort_and_format_imports

      # load is not an import, so it stays in place
      # require after load is a separate block
      expect(File.read(file_path)).to eq(<<~RUBY)
        load 'some_file'
        require 'json'
      RUBY
    end
  end
end
