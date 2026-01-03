# frozen_string_literal: true

require "isort"

RSpec.describe Isort::WrapModes do
  describe "constants" do
    it "defines all wrap mode constants" do
      expect(Isort::WrapModes::GRID).to eq(0)
      expect(Isort::WrapModes::VERTICAL).to eq(1)
      expect(Isort::WrapModes::HANGING_INDENT).to eq(2)
      expect(Isort::WrapModes::VERTICAL_HANGING_INDENT).to eq(3)
      expect(Isort::WrapModes::VERTICAL_GRID).to eq(4)
      expect(Isort::WrapModes::VERTICAL_GRID_GROUPED).to eq(5)
      expect(Isort::WrapModes::VERTICAL_GRID_GROUPED_NO_WRAP).to eq(6)
      expect(Isort::WrapModes::NOQA).to eq(7)
    end

    it "has a default mode" do
      expect(Isort::WrapModes::DEFAULT).to eq(Isort::WrapModes::VERTICAL_HANGING_INDENT)
    end

    it "has a MODES hash" do
      expect(Isort::WrapModes::MODES).to be_a(Hash)
      expect(Isort::WrapModes::MODES[:grid]).to eq(0)
      expect(Isort::WrapModes::MODES[:vertical]).to eq(1)
    end
  end

  describe ".get" do
    it "returns mode number for integer input" do
      expect(Isort::WrapModes.get(0)).to eq(0)
      expect(Isort::WrapModes.get(3)).to eq(3)
    end

    it "returns mode number for symbol input" do
      expect(Isort::WrapModes.get(:grid)).to eq(0)
      expect(Isort::WrapModes.get(:vertical)).to eq(1)
      expect(Isort::WrapModes.get(:hanging_indent)).to eq(2)
    end

    it "returns mode number for string input" do
      expect(Isort::WrapModes.get("grid")).to eq(0)
      expect(Isort::WrapModes.get("vertical")).to eq(1)
    end

    it "returns default for unknown mode" do
      expect(Isort::WrapModes.get(:unknown)).to eq(Isort::WrapModes::DEFAULT)
      expect(Isort::WrapModes.get(nil)).to eq(Isort::WrapModes::DEFAULT)
    end
  end

  describe ".needs_wrapping?" do
    it "returns true for lines exceeding max length" do
      long_line = "a" * 80
      expect(Isort::WrapModes.needs_wrapping?(long_line)).to be true
    end

    it "returns false for lines within max length" do
      short_line = "a" * 50
      expect(Isort::WrapModes.needs_wrapping?(short_line)).to be false
    end

    it "respects custom max_length" do
      line = "a" * 50
      expect(Isort::WrapModes.needs_wrapping?(line, max_length: 40)).to be true
      expect(Isort::WrapModes.needs_wrapping?(line, max_length: 60)).to be false
    end
  end

  describe ".wrap_comment" do
    it "returns single line for short comments" do
      comment = "# short comment"
      result = Isort::WrapModes.wrap_comment(comment)
      expect(result).to eq([comment])
    end

    it "wraps long comments into multiple lines" do
      long_comment = "# This is a very long comment that should be wrapped because it exceeds the maximum line length"
      result = Isort::WrapModes.wrap_comment(long_comment, max_length: 40)

      expect(result.length).to be > 1
      result.each do |line|
        expect(line.length).to be <= 40
      end
    end

    it "respects indentation" do
      comment = "# This is a long comment that needs wrapping into multiple lines for readability"
      result = Isort::WrapModes.wrap_comment(comment, max_length: 40, indent: "  ")

      result.each do |line|
        expect(line).to start_with("  ")
      end
    end
  end

  describe ".format_line" do
    let(:imports) { ["'json'", "'yaml'", "'csv'"] }

    context "with GRID mode" do
      it "formats imports in grid layout" do
        result = Isort::WrapModes.format_line(imports, mode: :grid, line_length: 30)
        expect(result).to be_a(String)
        expect(result).to include("'json'")
        expect(result).to include("'yaml'")
      end
    end

    context "with VERTICAL mode" do
      it "formats imports vertically" do
        result = Isort::WrapModes.format_line(imports, mode: :vertical)
        lines = result.split("\n")

        expect(lines.first).to include("(")
        expect(lines.last).to include(")")
      end
    end

    context "with HANGING_INDENT mode" do
      it "formats with continuation indent" do
        result = Isort::WrapModes.format_line(imports, mode: :hanging_indent, line_length: 20)
        expect(result).to be_a(String)
      end
    end

    context "with VERTICAL_HANGING_INDENT mode" do
      it "formats with vertical hanging indent" do
        result = Isort::WrapModes.format_line(imports, mode: :vertical_hanging_indent)
        lines = result.split("\n")

        expect(lines.first).to include("(")
        expect(lines.last).to include(")")
      end
    end

    context "with VERTICAL_GRID mode" do
      it "formats in vertical grid" do
        result = Isort::WrapModes.format_line(imports, mode: :vertical_grid, line_length: 30)
        expect(result).to include("(")
        expect(result).to include(")")
      end
    end

    context "with NOQA mode" do
      it "formats on single line with noqa comment" do
        result = Isort::WrapModes.format_line(imports, mode: :noqa)
        expect(result).to include("# noqa")
        expect(result).to include("'json'")
        expect(result).to include("'yaml'")
        expect(result).to include("'csv'")
      end
    end

    context "with single import" do
      it "returns single import unchanged for grid mode" do
        result = Isort::WrapModes.format_line(["'json'"], mode: :grid)
        expect(result).to eq("'json'")
      end
    end

    context "with custom indent" do
      it "respects indentation" do
        result = Isort::WrapModes.format_line(imports, mode: :vertical, indent: "  ")
        lines = result.split("\n")

        expect(lines.first).to start_with("  ")
      end
    end
  end
end
