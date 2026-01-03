# frozen_string_literal: true

require_relative "section"

module Isort
  # Represents a single import statement with all its metadata
  # This includes the raw line, type, sort key, and associated comments
  class ImportStatement
    IMPORT_TYPES = %i[require require_relative include extend autoload using].freeze
    TYPE_ORDER = {
      require: 0,
      require_relative: 1,
      include: 2,
      extend: 3,
      autoload: 4,
      using: 5
    }.freeze

    SKIP_PATTERN = /#\s*isort:\s*skip\b/i

    attr_reader :type, :raw_line, :sort_key, :leading_comments, :indentation, :skip_sorting, :section

    def initialize(raw_line:, type:, leading_comments: [], indentation: "")
      @raw_line = raw_line
      @type = type
      @leading_comments = leading_comments
      @indentation = indentation
      @sort_key = extract_sort_key
      @skip_sorting = has_skip_directive?
      @section = Section.classify(self)
    end

    # Check if this import has an isort:skip directive
    def has_skip_directive?
      @raw_line.match?(SKIP_PATTERN)
    end

    alias skip_sorting? skip_sorting

    # Returns the full representation including leading comments
    def to_s
      lines = []
      lines.concat(@leading_comments) unless @leading_comments.empty?
      lines << @raw_line
      lines.join
    end

    # Returns lines as an array (for reconstruction)
    def to_lines
      result = @leading_comments.dup
      result << @raw_line
      result
    end

    # For deduplication - normalized import path/module
    def normalized_key
      @normalized_key ||= begin
        stripped = @raw_line.strip
        # Extract the actual import value for comparison
        case @type
        when :require, :require_relative
          # Extract path from require 'path' or require "path"
          if (match = stripped.match(/^(?:require|require_relative)\s+['"]([^'"]+)['"]/))
            "#{@type}:#{match[1]}"
          else
            "#{@type}:#{stripped}"
          end
        when :include, :extend, :using
          # Extract module name
          if (match = stripped.match(/^(?:include|extend|using)\s+(\S+)/))
            "#{@type}:#{match[1]}"
          else
            "#{@type}:#{stripped}"
          end
        when :autoload
          # Extract constant and path
          if (match = stripped.match(/^autoload\s+:?(\w+)/))
            "#{@type}:#{match[1]}"
          else
            "#{@type}:#{stripped}"
          end
        else
          "#{@type}:#{stripped}"
        end
      end
    end

    # Compare for sorting - first by section, then by type order, then alphabetically
    def <=>(other)
      # First compare by section (stdlib, thirdparty, firstparty, localfolder)
      section_comparison = Section.order(@section) <=> Section.order(other.section)
      return section_comparison unless section_comparison.zero?

      # Then by type within section
      type_comparison = TYPE_ORDER[@type] <=> TYPE_ORDER[other.type]
      return type_comparison unless type_comparison.zero?

      # Finally alphabetically
      @sort_key <=> other.sort_key
    end

    private

    def extract_sort_key
      stripped = @raw_line.strip
      # Remove the keyword and extract the sortable part
      case @type
      when :require
        stripped.sub(/^require\s+/, "")
      when :require_relative
        stripped.sub(/^require_relative\s+/, "")
      when :include
        stripped.sub(/^include\s+/, "")
      when :extend
        stripped.sub(/^extend\s+/, "")
      when :autoload
        stripped.sub(/^autoload\s+/, "")
      when :using
        stripped.sub(/^using\s+/, "")
      else
        stripped
      end
    end
  end
end
