# frozen_string_literal: true

module Isort
  # Parses Ruby source lines and classifies them by type
  # This is the core component for understanding file structure
  class Parser
    # Line types that can be returned
    LINE_TYPES = %i[
      shebang
      magic_comment
      require
      require_relative
      include
      extend
      autoload
      using
      comment
      blank
      code
    ].freeze

    IMPORT_TYPES = %i[require require_relative include extend autoload using].freeze

    # Magic comment patterns (encoding, frozen_string_literal, etc.)
    MAGIC_COMMENT_PATTERN = /^#\s*(?:encoding|coding|frozen_string_literal|warn_indent|shareable_constant_value):/i

    # Skip directive patterns
    SKIP_LINE_PATTERN = /#\s*isort:\s*skip\b/i.freeze
    SKIP_FILE_PATTERN = /^#\s*isort:\s*skip_file\b/i.freeze

    def initialize
      @line_number = 0
    end

    # Classify a single line and return its type
    def classify_line(line, line_number: nil)
      @line_number = line_number if line_number
      stripped = line.to_s.strip

      return :blank if stripped.empty?
      return classify_comment(line, stripped) if stripped.start_with?("#")

      classify_code(stripped)
    end

    # Check if a line type is an import
    def import_type?(type)
      IMPORT_TYPES.include?(type)
    end

    # Extract the indentation from a line
    def extract_indentation(line)
      match = line.to_s.match(/^(\s*)/)
      match ? match[1] : ""
    end

    # Check if line is a shebang (must be line 1)
    def shebang?(line, line_number)
      line_number == 1 && line.to_s.strip.start_with?("#!")
    end

    # Check if line has an isort:skip directive
    def has_skip_directive?(line)
      line.to_s.match?(SKIP_LINE_PATTERN) && !line.to_s.match?(SKIP_FILE_PATTERN)
    end

    # Check if line has an isort:skip_file directive
    def has_skip_file_directive?(line)
      line.to_s.match?(SKIP_FILE_PATTERN)
    end

    private

    def classify_comment(line, stripped)
      # Check for shebang on first line
      return :shebang if @line_number == 1 && stripped.start_with?("#!")

      # Check for magic comments (only valid at top of file, but we classify anyway)
      return :magic_comment if stripped.match?(MAGIC_COMMENT_PATTERN)

      :comment
    end

    def classify_code(stripped)
      # Skip lines that are primarily string literals containing import keywords
      # e.g., puts "require 'json'" or error_msg = 'include Module'
      return :code if string_containing_import_keyword?(stripped)

      # Order matters - check more specific patterns first

      # require_relative must come before require
      return :require_relative if require_relative_line?(stripped)
      return :require if require_line?(stripped)
      return :include if include_line?(stripped)
      return :extend if extend_line?(stripped)
      return :autoload if autoload_line?(stripped)
      return :using if using_line?(stripped)

      :code
    end

    # Detect if a line is primarily a string that happens to contain import keywords
    # This prevents false positives like: puts "require 'json'" or x = "include Foo"
    def string_containing_import_keyword?(stripped)
      # If line starts with a string assignment or method call with string arg
      # and the import keyword appears inside quotes, it's not a real import

      # Pattern: variable = "...require..." or variable = '...require...'
      return true if stripped.match?(/^\w+\s*=\s*['"].*(?:require|require_relative|include|extend|autoload|using).*['"]/)

      # Pattern: method_call "...require..." or method_call '...require...'
      # e.g., puts "require 'json'"
      return true if stripped.match?(/^\w+\s+['"].*(?:require|require_relative|include|extend|autoload|using).*['"]/)

      # Pattern: method_call("...require...") - method with parens and string arg
      return true if stripped.match?(/^\w+\(["'].*(?:require|require_relative|include|extend|autoload|using).*["']\)/)

      # Check if import keyword appears after an opening quote (inside a string)
      # This catches cases like: desc "require the json gem"
      if stripped.include?('"') || stripped.include?("'")
        # Find position of first quote and import keyword
        first_quote_pos = [stripped.index('"'), stripped.index("'")].compact.min
        import_keywords = %w[require require_relative include extend autoload using]

        import_keywords.each do |keyword|
          keyword_pos = stripped.index(keyword)
          next unless keyword_pos

          # If keyword appears after a quote, it might be inside a string
          # But we need to ensure it's not at the start (real import)
          if first_quote_pos && keyword_pos > first_quote_pos && keyword_pos > 0
            return true
          end
        end
      end

      false
    end

    def require_line?(stripped)
      # Match: require 'foo' or require "foo" or require('foo')
      # But NOT: require_relative
      stripped.match?(/^require\s+['"]/) || stripped.match?(/^require\(['"]/)
    end

    def require_relative_line?(stripped)
      # Match: require_relative 'foo' or require_relative "foo"
      stripped.match?(/^require_relative\s+['"]/) || stripped.match?(/^require_relative\(['"]/)
    end

    def include_line?(stripped)
      # Match: include ModuleName or include(ModuleName)
      # But NOT: included, includes, include?
      stripped.match?(/^include\s+[A-Z]/) || stripped.match?(/^include\([A-Z]/)
    end

    def extend_line?(stripped)
      # Match: extend ModuleName
      # But NOT: extended, extends
      stripped.match?(/^extend\s+[A-Z]/) || stripped.match?(/^extend\([A-Z]/)
    end

    def autoload_line?(stripped)
      # Match: autoload :Constant, 'path' or autoload(:Constant, 'path')
      stripped.match?(/^autoload\s+:/) || stripped.match?(/^autoload\(:/)
    end

    def using_line?(stripped)
      # Match: using ModuleName
      stripped.match?(/^using\s+[A-Z]/) || stripped.match?(/^using\([A-Z]/)
    end
  end
end
