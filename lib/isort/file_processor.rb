# frozen_string_literal: true

require_relative "parser"
require_relative "import_block"
require_relative "import_statement"
require_relative "syntax_validator"

module Isort
  # Main orchestrator for processing Ruby files
  # Finds import blocks, sorts them, and reconstructs the file
  class FileProcessor
    SKIP_FILE_PATTERN = /^#\s*isort:\s*skip_file\b/i
    SKIP_LINE_PATTERN = /#\s*isort:\s*skip\b/i

    def initialize(file_path, options = {})
      @file_path = file_path
      @options = {
        check: false,
        diff: false,
        atomic: false,
        quiet: false,
        verbose: false
      }.merge(options)
      @parser = Parser.new
    end

    # Process the file - returns true if changes were made
    def process
      original_content = read_file_content
      return false if original_content.nil? || original_content.empty?

      # Check for skip_file directive
      check_skip_file_directive!(original_content)

      # Atomic mode: validate original syntax first
      validate_original_syntax!(original_content) if @options[:atomic]

      lines = parse_lines(original_content)
      return false if lines.empty?

      # Find all import blocks in the file
      blocks_with_positions = find_import_blocks(lines)
      return false if blocks_with_positions.empty?

      # Sort each block
      blocks_with_positions.each do |block_info|
        block_info[:block].sort_and_dedupe!
      end

      # Reconstruct the file with sorted blocks
      new_content = reconstruct_file(lines, blocks_with_positions)

      # No changes needed
      return false if new_content == original_content

      # Atomic mode: validate new syntax before writing
      validate_new_syntax!(new_content) if @options[:atomic]

      # Write the file
      write_file(new_content)
      true
    rescue ArgumentError => e
      # Handle encoding errors from strip/other string operations
      if e.message.include?("invalid byte sequence")
        raise Encoding::CompatibilityError, "Invalid encoding in #{@file_path}: #{e.message}"
      end

      raise
    end

    # Check if file would change (dry-run mode for --check)
    # Returns true if file would be modified, false otherwise
    def check
      original_content = read_file_content
      return false if original_content.nil? || original_content.empty?

      # Check for skip_file directive
      begin
        check_skip_file_directive!(original_content)
      rescue FileSkipped
        return false
      end

      lines = parse_lines(original_content)
      return false if lines.empty?

      blocks_with_positions = find_import_blocks(lines)
      return false if blocks_with_positions.empty?

      # Sort each block (on a copy)
      blocks_with_positions.each do |block_info|
        block_info[:block].sort_and_dedupe!
      end

      new_content = reconstruct_file(lines, blocks_with_positions)
      new_content != original_content
    end

    # Get diff of changes without applying (for --diff mode)
    # Returns diff string or nil if no changes
    def diff
      original_content = read_file_content
      return nil if original_content.nil? || original_content.empty?

      # Check for skip_file directive
      begin
        check_skip_file_directive!(original_content)
      rescue FileSkipped
        return nil
      end

      lines = parse_lines(original_content)
      return nil if lines.empty?

      blocks_with_positions = find_import_blocks(lines)
      return nil if blocks_with_positions.empty?

      # Sort each block (on a copy)
      blocks_with_positions.each do |block_info|
        block_info[:block].sort_and_dedupe!
      end

      new_content = reconstruct_file(lines, blocks_with_positions)
      return nil if new_content == original_content

      generate_diff(original_content, new_content)
    end

    private

    def read_file_content
      content = File.read(@file_path, encoding: "UTF-8")

      unless content.valid_encoding?
        raise Encoding::CompatibilityError, "Invalid encoding in #{@file_path}: contains invalid UTF-8 bytes"
      end

      # Normalize line endings
      content.gsub("\r\n", "\n").gsub("\r", "\n")
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
      raise Encoding::CompatibilityError, "Invalid encoding in #{@file_path}: #{e.message}"
    end

    def parse_lines(content)
      content.lines(chomp: false).map { |line| line }
    end

    def check_skip_file_directive!(content)
      # Check first 50 lines for skip_file directive
      content.lines.first(50).each do |line|
        raise FileSkipped.new(@file_path, "isort:skip_file directive") if line.match?(SKIP_FILE_PATTERN)
      end
    end

    def validate_original_syntax!(content)
      return if SyntaxValidator.valid?(content)

      raise ExistingSyntaxErrors, @file_path
    end

    def validate_new_syntax!(content)
      return if SyntaxValidator.valid?(content)

      raise IntroducedSyntaxErrors, @file_path
    end

    def generate_diff(original, modified)
      require "tempfile"

      original_file = Tempfile.new(["original", ".rb"])
      modified_file = Tempfile.new(["modified", ".rb"])

      begin
        original_file.write(original)
        original_file.flush
        modified_file.write(modified)
        modified_file.flush

        # Use unified diff format
        diff_output = `diff -u "#{original_file.path}" "#{modified_file.path}" 2>/dev/null`

        # Replace temp file paths with actual file path in diff header
        diff_output = diff_output.gsub(original_file.path, "#{@file_path} (original)")
        diff_output = diff_output.gsub(modified_file.path, "#{@file_path} (sorted)")

        diff_output.empty? ? nil : diff_output
      ensure
        original_file.close
        original_file.unlink
        modified_file.close
        modified_file.unlink
      end
    end

    def write_file(content)
      File.write(@file_path, content)
    end

    # Find all import blocks in the file
    # Returns array of { block: ImportBlock, start_line: Int, end_line: Int }
    def find_import_blocks(lines)
      blocks = []
      current_block = nil
      pending_comments = []
      pending_blanks = []
      in_multiline_string = false
      heredoc_delimiter = nil

      lines.each_with_index do |line, index|
        line_num = index + 1

        # Handle potential encoding issues in line processing
        begin
          stripped = line.to_s.strip
        rescue ArgumentError
          # If we can't process the line, treat it as code
          finalize_block(current_block, blocks, index, pending_blanks)
          current_block = nil
          pending_comments = []
          pending_blanks = []
          next
        end

        indentation = @parser.extract_indentation(line)

        # Track heredoc state
        if heredoc_delimiter
          heredoc_delimiter = nil if stripped == heredoc_delimiter
          next
        end

        # Check for heredoc start
        if (heredoc_match = line.match(/<<[-~]?['"]?(\w+)['"]?/))
          heredoc_delimiter = heredoc_match[1]
        end

        # Skip multiline strings (basic detection)
        if in_multiline_string
          in_multiline_string = false if stripped.end_with?('"""') || stripped.end_with?("'''")
          next
        end

        if stripped.start_with?('"""') || stripped.start_with?("'''")
          in_multiline_string = true unless stripped.count(stripped[0..2]) >= 2
          next
        end

        line_type = @parser.classify_line(line, line_number: line_num)

        case line_type
        when :shebang, :magic_comment
          # These stay in place, finalize any current block
          finalize_block(current_block, blocks, index - 1, pending_blanks)
          current_block = nil
          pending_comments = []
          pending_blanks = []

        when :comment
          # Accumulate comments - they might belong to the next import
          # But only if there's no blank line separating them
          if pending_blanks.empty?
            pending_comments << line
          else
            # There was a blank line before this comment, so previous comments
            # are "floating" and don't belong to imports - clear them
            pending_comments = [line]
            pending_blanks = []
          end

        when :blank
          if current_block && !current_block.empty?
            # Track blank lines - more than 1 consecutive ends the block
            pending_blanks << line
            if pending_blanks.size > 1
              # End current block (don't include the blank lines in the block)
              # The blank lines will remain between blocks in reconstruction
              finalize_block(current_block, blocks, index - pending_blanks.size, [])
              current_block = nil
              pending_comments = []
              # DON'T carry over pending_blanks - they stay as separators between blocks
              pending_blanks = []
            end
          else
            # Not in a block - blank line separates any pending comments from next import
            if pending_comments.any?
              # Comments followed by blank line are "floating" - don't attach to next import
              pending_comments = []
            end
            pending_blanks << line
          end

        when :require, :require_relative, :include, :extend, :autoload, :using
          # Reset pending blanks when we see an import (they're part of the block)
          if current_block && !pending_blanks.empty?
            # Single blank line between imports is OK, attach to import's comments
            pending_comments = pending_blanks + pending_comments
            pending_blanks = []
          end

          # This is an import line!
          if current_block.nil?
            current_block = ImportBlock.new(indentation: indentation)
            # The block starts at the first pending comment or this line
            if pending_comments.any? || pending_blanks.any?
              current_block.start_line = index - pending_comments.size - pending_blanks.size
              current_block.leading_content = pending_blanks.dup
            else
              current_block.start_line = index
            end
          end

          # Handle indentation change - might be a new block
          if current_block.indentation != indentation && !current_block.empty?
            # Different indentation, finalize current block and start new one
            finalize_block(current_block, blocks, index - 1 - pending_comments.size, [])

            current_block = ImportBlock.new(indentation: indentation)
            if pending_comments.any? || pending_blanks.any?
              current_block.start_line = index - pending_comments.size - pending_blanks.size
              current_block.leading_content = pending_blanks.dup
            else
              current_block.start_line = index
            end
          end

          # Create the import statement with its leading comments
          statement = ImportStatement.new(
            raw_line: line,
            type: line_type,
            leading_comments: pending_comments.dup,
            indentation: indentation
          )
          current_block.add_statement(statement)

          pending_comments = []
          pending_blanks = []
          current_block.end_line = index

        when :code
          # Non-import code - finalize any current block
          finalize_block(current_block, blocks, index - 1, pending_blanks)
          current_block = nil
          pending_comments = []
          pending_blanks = []
        end
      end

      # Finalize any remaining block at end of file
      # Include trailing comments if they exist
      if current_block && !current_block.empty?
        # Add any trailing comments to the last statement
        current_block.end_line = if pending_comments.any?
                                   # These are orphan comments at end - don't include in block range
                                   lines.size - 1 - pending_blanks.size - pending_comments.size
                                 else
                                   lines.size - 1 - pending_blanks.size
                                 end
        blocks << { block: current_block, start_line: current_block.start_line, end_line: current_block.end_line }
      end

      blocks
    end

    def finalize_block(block, blocks, end_index, pending_blanks)
      return unless block && !block.empty?

      block.end_line = [end_index - pending_blanks.size, block.start_line].max
      blocks << { block: block, start_line: block.start_line, end_line: block.end_line }
    end

    # Reconstruct the file with sorted import blocks
    def reconstruct_file(original_lines, blocks_with_positions)
      return original_lines.join if blocks_with_positions.empty?

      result = []
      last_end = -1

      # Sort blocks by start position
      sorted_blocks = blocks_with_positions.sort_by { |b| b[:start_line] }

      sorted_blocks.each_with_index do |block_info, block_index|
        start_line = block_info[:start_line]
        end_line = block_info[:end_line]
        block = block_info[:block]

        # Add lines before this block (from last_end+1 to start_line-1)
        if start_line > last_end + 1
          lines_between = (last_end + 1...start_line).map { |i| original_lines[i] }.compact

          # If lines between consecutive import blocks are only blank lines,
          # normalize to a single blank line
          if block_index.positive? && lines_between.all? { |l| l.strip.empty? }
            # Add single blank line if there were any blanks
            result << "\n" unless lines_between.empty?
          else
            # Add all lines as-is
            lines_between.each { |line| result << line }
          end
        end

        # Add the sorted block
        sorted_lines = block.to_lines
        result.concat(sorted_lines)

        last_end = end_line
      end

      # Add remaining lines after the last block
      if last_end < original_lines.size - 1
        ((last_end + 1)...original_lines.size).each do |i|
          result << original_lines[i] if original_lines[i]
        end
      end

      # Join and ensure trailing newline
      content = result.join
      content = "#{content.rstrip}\n" unless content.empty?
      content
    end
  end
end
