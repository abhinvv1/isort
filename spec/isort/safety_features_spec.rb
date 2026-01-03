# frozen_string_literal: true

require "tempfile"
require "isort"

RSpec.describe "Isort Safety Features" do
  describe "SyntaxValidator" do
    describe ".valid?" do
      it "returns true for valid Ruby code" do
        expect(Isort::SyntaxValidator.valid?("puts 'hello'")).to be true
      end

      it "returns true for empty code" do
        expect(Isort::SyntaxValidator.valid?("")).to be true
      end

      it "returns false for invalid Ruby syntax" do
        expect(Isort::SyntaxValidator.valid?("def foo(")).to be false
      end

      it "returns false for unclosed strings" do
        expect(Isort::SyntaxValidator.valid?('puts "hello')).to be false
      end

      it "returns true for complex valid code" do
        code = <<~RUBY
          require 'json'

          class Foo
            def bar
              puts 'hello'
            end
          end
        RUBY
        expect(Isort::SyntaxValidator.valid?(code)).to be true
      end
    end

    describe ".check_syntax" do
      it "returns nil for valid code" do
        expect(Isort::SyntaxValidator.check_syntax("puts 'hello'")).to be_nil
      end

      it "returns error message for invalid code" do
        result = Isort::SyntaxValidator.check_syntax("def foo(")
        expect(result).to be_a(String)
        expect(result).to include("syntax error")
      end
    end
  end

  describe "FileProcessor --check mode" do
    it "returns true when file would change" do
      file = Tempfile.new(["test", ".rb"])
      begin
        file.write("require 'yaml'\nrequire 'json'\n")
        file.flush

        processor = Isort::FileProcessor.new(file.path, check: true)
        expect(processor.check).to be true
      ensure
        file.close
        file.unlink
      end
    end

    it "returns false when file is already sorted" do
      file = Tempfile.new(["test", ".rb"])
      begin
        file.write("require 'json'\nrequire 'yaml'\n")
        file.flush

        processor = Isort::FileProcessor.new(file.path, check: true)
        expect(processor.check).to be false
      ensure
        file.close
        file.unlink
      end
    end

    it "returns false for files with no imports" do
      file = Tempfile.new(["test", ".rb"])
      begin
        file.write("puts 'hello'\n")
        file.flush

        processor = Isort::FileProcessor.new(file.path, check: true)
        expect(processor.check).to be false
      ensure
        file.close
        file.unlink
      end
    end
  end

  describe "FileProcessor --diff mode" do
    it "returns diff output when file would change" do
      file = Tempfile.new(["test", ".rb"])
      begin
        file.write("require 'yaml'\nrequire 'json'\n")
        file.flush

        processor = Isort::FileProcessor.new(file.path, diff: true)
        diff = processor.diff

        expect(diff).not_to be_nil
        expect(diff).to include("-require 'yaml'")
        expect(diff).to include("+require 'yaml'") # yaml moves down
      ensure
        file.close
        file.unlink
      end
    end

    it "returns nil when file is already sorted" do
      file = Tempfile.new(["test", ".rb"])
      begin
        file.write("require 'json'\nrequire 'yaml'\n")
        file.flush

        processor = Isort::FileProcessor.new(file.path, diff: true)
        expect(processor.diff).to be_nil
      ensure
        file.close
        file.unlink
      end
    end
  end

  describe "FileProcessor --atomic mode" do
    it "sorts valid files normally" do
      file = Tempfile.new(["test", ".rb"])
      begin
        file.write("require 'yaml'\nrequire 'json'\n")
        file.flush

        processor = Isort::FileProcessor.new(file.path, atomic: true)
        result = processor.process

        expect(result).to be true
        expect(File.read(file.path)).to eq("require 'json'\nrequire 'yaml'\n")
      ensure
        file.close
        file.unlink
      end
    end

    it "raises ExistingSyntaxErrors for files with syntax errors" do
      file = Tempfile.new(["test", ".rb"])
      begin
        file.write("require 'json'\ndef foo(\n")
        file.flush

        processor = Isort::FileProcessor.new(file.path, atomic: true)

        expect { processor.process }.to raise_error(Isort::ExistingSyntaxErrors)
      ensure
        file.close
        file.unlink
      end
    end
  end

  describe "Skip directives" do
    describe "isort:skip_file" do
      it "skips files with skip_file directive" do
        file = Tempfile.new(["test", ".rb"])
        begin
          file.write("# isort:skip_file\nrequire 'yaml'\nrequire 'json'\n")
          file.flush

          processor = Isort::FileProcessor.new(file.path)

          expect { processor.process }.to raise_error(Isort::FileSkipped)
        ensure
          file.close
          file.unlink
        end
      end

      it "handles skip_file with different spacing" do
        file = Tempfile.new(["test", ".rb"])
        begin
          file.write("#  isort:  skip_file\nrequire 'yaml'\nrequire 'json'\n")
          file.flush

          processor = Isort::FileProcessor.new(file.path)

          expect { processor.process }.to raise_error(Isort::FileSkipped)
        ensure
          file.close
          file.unlink
        end
      end

      it "is case insensitive" do
        file = Tempfile.new(["test", ".rb"])
        begin
          file.write("# ISORT:SKIP_FILE\nrequire 'yaml'\nrequire 'json'\n")
          file.flush

          processor = Isort::FileProcessor.new(file.path)

          expect { processor.process }.to raise_error(Isort::FileSkipped)
        ensure
          file.close
          file.unlink
        end
      end
    end

    describe "isort:skip" do
      it "keeps import with skip directive in place" do
        file = Tempfile.new(["test", ".rb"])
        begin
          file.write("require 'yaml' # isort:skip\nrequire 'json'\nrequire 'csv'\n")
          file.flush

          processor = Isort::FileProcessor.new(file.path)
          processor.process

          content = File.read(file.path)
          lines = content.split("\n")

          # yaml should stay at first position (it was skipped)
          expect(lines[0]).to eq("require 'yaml' # isort:skip")
          # csv and json are sorted
          expect(lines[1]).to eq("require 'csv'")
          expect(lines[2]).to eq("require 'json'")
        ensure
          file.close
          file.unlink
        end
      end

      it "handles multiple skip directives" do
        file = Tempfile.new(["test", ".rb"])
        begin
          file.write(<<~RUBY)
            require 'z_lib' # isort:skip
            require 'yaml'
            require 'a_lib' # isort:skip
            require 'json'
          RUBY
          file.flush

          processor = Isort::FileProcessor.new(file.path)
          processor.process

          content = File.read(file.path)

          # Skip-marked imports should stay roughly in their relative positions
          expect(content).to include("require 'z_lib' # isort:skip")
          expect(content).to include("require 'a_lib' # isort:skip")
          # Non-skipped imports should be sorted
          expect(content).to include("require 'json'")
          expect(content).to include("require 'yaml'")
        ensure
          file.close
          file.unlink
        end
      end

      it "is case insensitive" do
        file = Tempfile.new(["test", ".rb"])
        begin
          file.write("require 'yaml' # ISORT:SKIP\nrequire 'json'\n")
          file.flush

          processor = Isort::FileProcessor.new(file.path)
          processor.process

          content = File.read(file.path)
          lines = content.split("\n")

          # yaml should stay at first position
          expect(lines[0]).to eq("require 'yaml' # ISORT:SKIP")
        ensure
          file.close
          file.unlink
        end
      end
    end
  end

  describe "Section-based grouping" do
    it "separates stdlib from thirdparty requires" do
      file = Tempfile.new(["test", ".rb"])
      begin
        file.write("require 'active_support'\nrequire 'json'\nrequire 'rails'\nrequire 'csv'\n")
        file.flush

        processor = Isort::FileProcessor.new(file.path)
        processor.process

        content = File.read(file.path)
        lines = content.strip.split("\n").reject(&:empty?)

        # stdlib (csv, json) should come before thirdparty (active_support, rails)
        csv_pos = lines.index { |l| l.include?("'csv'") }
        json_pos = lines.index { |l| l.include?("'json'") }
        active_support_pos = lines.index { |l| l.include?("'active_support'") }
        rails_pos = lines.index { |l| l.include?("'rails'") }

        expect(csv_pos).to be < active_support_pos
        expect(json_pos).to be < active_support_pos
        expect(csv_pos).to be < rails_pos
        expect(json_pos).to be < rails_pos
      ensure
        file.close
        file.unlink
      end
    end

    it "puts require_relative last (localfolder section)" do
      file = Tempfile.new(["test", ".rb"])
      begin
        file.write("require_relative 'helper'\nrequire 'json'\ninclude MyModule\n")
        file.flush

        processor = Isort::FileProcessor.new(file.path)
        processor.process

        content = File.read(file.path)
        lines = content.strip.split("\n").reject(&:empty?)

        json_pos = lines.index { |l| l.include?("'json'") }
        include_pos = lines.index { |l| l.include?("include") }
        helper_pos = lines.index { |l| l.include?("'helper'") }

        # Order: stdlib require, firstparty include, localfolder require_relative
        expect(json_pos).to be < include_pos
        expect(include_pos).to be < helper_pos
      ensure
        file.close
        file.unlink
      end
    end

    it "adds blank lines between sections" do
      file = Tempfile.new(["test", ".rb"])
      begin
        file.write("require_relative 'helper'\nrequire 'json'\n")
        file.flush

        processor = Isort::FileProcessor.new(file.path)
        processor.process

        content = File.read(file.path)

        # Should have blank line between stdlib and localfolder sections
        expect(content).to include("require 'json'\n\nrequire_relative 'helper'")
      ensure
        file.close
        file.unlink
      end
    end
  end

  describe "CLI integration" do
    describe "--check flag" do
      it "exits with 0 when file is sorted" do
        file = Tempfile.new(["test", ".rb"])
        begin
          file.write("require 'json'\nrequire 'yaml'\n")
          file.flush

          # Test via process_file directly since CLI.start calls exit
          result = Isort::CLI.process_file(file.path, { check: true, quiet: true })
          expect(result).to eq(0)
        ensure
          file.close
          file.unlink
        end
      end

      it "exits with 1 when file needs sorting" do
        file = Tempfile.new(["test", ".rb"])
        begin
          file.write("require 'yaml'\nrequire 'json'\n")
          file.flush

          result = Isort::CLI.process_file(file.path, { check: true, quiet: true })
          expect(result).to eq(1)
        ensure
          file.close
          file.unlink
        end
      end
    end

    describe "--diff flag" do
      it "shows diff when file needs sorting" do
        file = Tempfile.new(["test", ".rb"])
        begin
          file.write("require 'yaml'\nrequire 'json'\n")
          file.flush

          output = StringIO.new
          original_stdout = $stdout
          $stdout = output

          result = Isort::CLI.process_file(file.path, { diff: true })

          $stdout = original_stdout

          expect(result).to eq(1)
          expect(output.string).to include("-require 'yaml'")
        ensure
          file.close
          file.unlink
        end
      end
    end

    describe "--atomic flag" do
      it "sorts valid files" do
        file = Tempfile.new(["test", ".rb"])
        begin
          file.write("require 'yaml'\nrequire 'json'\n")
          file.flush

          result = Isort::CLI.process_file(file.path, { atomic: true, quiet: true })
          expect(result).to eq(0)
          expect(File.read(file.path)).to eq("require 'json'\nrequire 'yaml'\n")
        ensure
          file.close
          file.unlink
        end
      end

      it "returns error for files with existing syntax errors" do
        file = Tempfile.new(["test", ".rb"])
        begin
          file.write("require 'json'\ndef foo(\n")
          file.flush

          result = Isort::CLI.process_file(file.path, { atomic: true, quiet: true })
          expect(result).to eq(1)
        ensure
          file.close
          file.unlink
        end
      end
    end
  end
end
