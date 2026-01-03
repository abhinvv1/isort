# frozen_string_literal: true

module Isort
  # Wrap modes for handling long import lines
  module WrapModes
    # Mode 0: Grid - wraps with opening parenthesis on first line
    # require 'a', 'b', 'c',
    #         'd', 'e'
    GRID = 0

    # Mode 1: Vertical - one import per line after opening paren
    # require(
    #     'a',
    #     'b',
    #     'c',
    # )
    VERTICAL = 1

    # Mode 2: Hanging indent - continuation lines have extra indent
    # require 'a', 'b', 'c',
    #     'd', 'e'
    HANGING_INDENT = 2

    # Mode 3: Vertical hanging indent - combines vertical and hanging
    # require(
    #     'a',
    #     'b',
    #     'c',
    # )
    VERTICAL_HANGING_INDENT = 3

    # Mode 4: Vertical grid - like grid but vertical
    # require(
    #     'a', 'b',
    #     'c', 'd',
    # )
    VERTICAL_GRID = 4

    # Mode 5: Vertical grid grouped - groups related imports
    # require('a', 'b',
    #         'c', 'd')
    VERTICAL_GRID_GROUPED = 5

    # Mode 6: Vertical grid grouped with trailing comma
    VERTICAL_GRID_GROUPED_NO_WRAP = 6

    # Mode 7: NOQA - single line with comment to disable linting
    NOQA = 7

    # Default mode
    DEFAULT = VERTICAL_HANGING_INDENT

    # All available modes
    MODES = {
      grid: GRID,
      vertical: VERTICAL,
      hanging_indent: HANGING_INDENT,
      vertical_hanging_indent: VERTICAL_HANGING_INDENT,
      vertical_grid: VERTICAL_GRID,
      vertical_grid_grouped: VERTICAL_GRID_GROUPED,
      vertical_grid_grouped_no_wrap: VERTICAL_GRID_GROUPED_NO_WRAP,
      noqa: NOQA
    }.freeze

    class << self
      # Get mode by name or number
      def get(mode)
        case mode
        when Integer
          mode
        when Symbol, String
          MODES[mode.to_sym] || DEFAULT
        else
          DEFAULT
        end
      end

      # Format a multi-import line according to the wrap mode
      # for formatting long autoload statements or future multi-require support
      def format_line(imports, mode: DEFAULT, line_length: 79, indent: "")
        mode = get(mode)

        case mode
        when GRID
          format_grid(imports, line_length, indent)
        when VERTICAL
          format_vertical(imports, indent)
        when HANGING_INDENT
          format_hanging_indent(imports, line_length, indent)
        when VERTICAL_HANGING_INDENT
          format_vertical_hanging_indent(imports, indent)
        when VERTICAL_GRID
          format_vertical_grid(imports, line_length, indent)
        when VERTICAL_GRID_GROUPED
          format_vertical_grid_grouped(imports, line_length, indent)
        when NOQA
          format_noqa(imports, indent)
        else
          format_vertical_hanging_indent(imports, indent)
        end
      end

      # Check if a line needs wrapping based on line length
      def needs_wrapping?(line, max_length: 79)
        line.length > max_length
      end

      # Split a long import line into multiple lines
      # Currently used for comments/documentation, as Ruby imports are typically single-line
      def wrap_comment(comment, max_length: 79, indent: "")
        return [comment] if comment.length <= max_length

        words = comment.split(/\s+/)
        lines = []
        current_line = indent.dup

        words.each do |word|
          if current_line.length + word.length + 1 > max_length && current_line != indent
            lines << current_line.rstrip
            current_line = "#{indent}# #{word}"
          else
            current_line += current_line == indent ? "# #{word}" : " #{word}"
          end
        end

        lines << current_line.rstrip unless current_line.strip.empty?
        lines
      end

      private

      def format_grid(imports, line_length, indent)
        return imports.first if imports.size == 1

        lines = []
        current_line = indent.dup

        imports.each_with_index do |imp, idx|
          separator = idx < imports.size - 1 ? ", " : ""
          potential = current_line + imp + separator

          if potential.length > line_length && current_line != indent
            lines << current_line.rstrip.chomp(",")
            current_line = "#{indent}#{imp}#{separator}"
          else
            current_line = potential
          end
        end

        lines << current_line.rstrip
        lines.join("\n")
      end

      def format_vertical(imports, indent)
        inner_indent = "#{indent}    "
        result = ["#{indent}("]
        imports.each do |imp|
          result << "#{inner_indent}#{imp},"
        end
        result << "#{indent})"
        result.join("\n")
      end

      def format_hanging_indent(imports, line_length, indent)
        continuation_indent = "#{indent}    "
        lines = []
        current_line = indent.dup

        imports.each_with_index do |imp, idx|
          separator = idx < imports.size - 1 ? ", " : ""

          if idx == 0
            current_line += imp + separator
          elsif current_line.length + imp.length + separator.length > line_length
            lines << current_line.rstrip.chomp(",")
            current_line = "#{continuation_indent}#{imp}#{separator}"
          else
            current_line += imp + separator
          end
        end

        lines << current_line.rstrip
        lines.join("\n")
      end

      def format_vertical_hanging_indent(imports, indent)
        inner_indent = "#{indent}    "
        result = ["#{indent}("]
        imports.each do |imp|
          result << "#{inner_indent}#{imp},"
        end
        result << "#{indent})"
        result.join("\n")
      end

      def format_vertical_grid(imports, line_length, indent)
        inner_indent = "#{indent}    "
        result = ["#{indent}("]
        current_line = inner_indent.dup

        imports.each_with_index do |imp, idx|
          separator = idx < imports.size - 1 ? ", " : ","

          if current_line.length + imp.length + separator.length > line_length && current_line != inner_indent
            result << current_line.rstrip
            current_line = "#{inner_indent}#{imp}#{separator}"
          else
            current_line += current_line == inner_indent ? "#{imp}#{separator}" : " #{imp}#{separator}"
          end
        end

        result << current_line.rstrip unless current_line.strip.empty?
        result << "#{indent})"
        result.join("\n")
      end

      def format_vertical_grid_grouped(imports, line_length, indent)
        inner_indent = "#{indent}    "
        current_line = "#{indent}("

        imports.each_with_index do |imp, idx|
          separator = idx < imports.size - 1 ? ", " : ""

          if current_line.length + imp.length + separator.length > line_length
            current_line += "\n#{inner_indent}#{imp}#{separator}"
          else
            current_line += imp + separator
          end
        end

        current_line + ")"
      end

      def format_noqa(imports, indent)
        line = imports.join(", ")
        "#{indent}#{line}  # noqa"
      end
    end
  end
end
