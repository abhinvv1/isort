# frozen_string_literal: true

require "fileutils"
require "tempfile"
require "isort"

RSpec.describe "Isort::FileSorter" do
  let(:file_path) { Tempfile.new(["test", ".rb"]) }
  let(:sorter) { Isort::FileSorter.new(file_path.path) }

  after do
    file_path.close
    file_path.unlink
  end

  describe "#sort_and_format_imports" do
    context "when the file contains no imports" do
      it "does not modify the file and keeps it unchanged" do
        original_content = "puts 'Hello, world!'"
        File.write(file_path, original_content)

        sorter = Isort::FileSorter.new(file_path)
        sorter.sort_and_format_imports

        expect(File.read(file_path)).to eq(original_content)
      end

      it "does not add any new lines to the file" do
        original_content = "puts 'Hello, world!'"
        File.write(file_path, original_content)

        sorter = Isort::FileSorter.new(file_path)
        sorter.sort_and_format_imports

        expect(File.read(file_path)).to eq(original_content)
      end
    end

    context "when the file contains only comments" do
      it "does not modify the file and keeps it unchanged" do
        original_content = "# This is a comment\n# Another comment"
        File.write(file_path, original_content)

        sorter = Isort::FileSorter.new(file_path)
        sorter.sort_and_format_imports

        expect(File.read(file_path)).to eq(original_content)
      end
    end

    context "when the file contains imports" do
      context "with no duplicates" do
        it "sorts and formats the imports correctly" do
          original_content = <<~RUBY
            extend AnotherModule
            include SomeModule
            # This is a comment
            autoload :CSV, 'csv'
            using SomeRefinement
          RUBY

          expected_content = <<~RUBY
            include SomeModule

            extend AnotherModule

            # This is a comment
            autoload :CSV, 'csv'

            using SomeRefinement
          RUBY

          File.write(file_path, original_content)

          sorter = Isort::FileSorter.new(file_path)
          sorter.sort_and_format_imports

          expect(File.read(file_path)).to eq(expected_content)
        end
      end

      context "with duplicate imports" do
        it "removes duplicate imports and keeps associated comments" do
          original_content = <<~RUBY
            extend AnotherModule
            include SomeModule
            include SomeModule
            # Comment for autoload
            autoload :CSV, 'csv'
            autoload :CSV, 'csv'
            using SomeRefinement
          RUBY

          # Duplicates are removed per user preference
          expected_content = <<~RUBY
            include SomeModule

            extend AnotherModule

            # Comment for autoload
            autoload :CSV, 'csv'

            using SomeRefinement
          RUBY

          File.write(file_path, original_content)

          sorter = Isort::FileSorter.new(file_path)
          sorter.sort_and_format_imports

          expect(File.read(file_path)).to eq(expected_content)
        end
      end

      context "with already sorted imports" do
        it "adds proper spacing between groups" do
          original_content = <<~RUBY
            include SomeModule
            extend AnotherModule
            autoload :CSV, 'csv'
            using SomeRefinement
          RUBY

          expected_content = <<~RUBY
            include SomeModule

            extend AnotherModule

            autoload :CSV, 'csv'

            using SomeRefinement
          RUBY

          File.write(file_path, original_content)

          sorter = Isort::FileSorter.new(file_path)
          sorter.sort_and_format_imports

          expect(File.read(file_path)).to eq(expected_content)
        end
      end

      context "with comments preceding imports" do
        it "keeps the comments attached to the correct import and sorts correctly" do
          original_content = <<~RUBY
            # This is a comment for include
            include SomeModule
            # This is a comment for extend
            extend AnotherModule
            # Comment for autoload
            autoload :CSV, 'csv'
            using SomeRefinement
          RUBY

          expected_content = <<~RUBY
            # This is a comment for include
            include SomeModule

            # This is a comment for extend
            extend AnotherModule

            # Comment for autoload
            autoload :CSV, 'csv'

            using SomeRefinement
          RUBY

          File.write(file_path, original_content)

          sorter = Isort::FileSorter.new(file_path)
          sorter.sort_and_format_imports

          expect(File.read(file_path)).to eq(expected_content)
        end
      end
    end

    context "when there are mixed import types with comments" do
      it "preserves comments and orders imports correctly" do
        original_content = <<~RUBY
          # This is a comment before using
          using SomeRefinement
          # This is a comment before autoload
          autoload :CSV, 'csv'
          # Comment before extend
          extend AnotherModule
          # Comment before include
          include SomeModule
        RUBY

        expected_content = <<~RUBY
          # Comment before include
          include SomeModule

          # Comment before extend
          extend AnotherModule

          # This is a comment before autoload
          autoload :CSV, 'csv'

          # This is a comment before using
          using SomeRefinement
        RUBY

        File.write(file_path, original_content)

        sorter = Isort::FileSorter.new(file_path)
        sorter.sort_and_format_imports

        expect(File.read(file_path)).to eq(expected_content)
      end
    end

    context "when the file has only one import" do
      it "does not change the file content" do
        original_content = <<~RUBY
          include SomeModule
        RUBY

        File.write(file_path, original_content)

        sorter = Isort::FileSorter.new(file_path)
        sorter.sort_and_format_imports

        expect(File.read(file_path)).to eq(original_content)
      end
    end

    context "when the file has imports with multiple blank lines between groups" do
      it "normalizes to single blank line between groups" do
        original_content = <<~RUBY
          include SomeModule


          extend AnotherModule
          # Comment for autoload
          autoload :CSV, 'csv'


        RUBY

        expected_content = <<~RUBY
          include SomeModule

          extend AnotherModule

          # Comment for autoload
          autoload :CSV, 'csv'
        RUBY

        File.write(file_path, original_content)

        sorter = Isort::FileSorter.new(file_path)
        sorter.sort_and_format_imports

        expect(File.read(file_path)).to eq(expected_content)
      end
    end
  end
end
