# frozen_string_literal: true

require_relative "import_statement"

module Isort
  # Represents a contiguous block of import statements
  # Handles sorting, deduplication, and reconstruction
  class ImportBlock
    attr_reader :statements, :indentation
    attr_accessor :start_line, :end_line, :leading_content, :trailing_blank_lines

    def initialize(indentation: "")
      @statements = []
      @start_line = nil
      @end_line = nil
      @indentation = indentation
      @leading_content = [] # Comments/blanks before first import in block
      @trailing_blank_lines = 0
    end

    def add_statement(statement)
      @statements << statement
    end

    def empty?
      @statements.empty?
    end

    def size
      @statements.size
    end

    # Sort statements by type then alphabetically, and remove duplicates
    # Imports with isort:skip directive stay in their original position
    def sort_and_dedupe!
      return if @statements.empty?

      # Separate skipped and sortable statements
      skipped_with_positions = []
      sortable = []

      @statements.each_with_index do |stmt, index|
        if stmt.skip_sorting?
          skipped_with_positions << { statement: stmt, position: index }
        else
          sortable << stmt
        end
      end

      # Sort only the sortable statements
      sortable.sort!

      # Remove duplicates from sortable (keep first occurrence with its comments)
      seen = {}
      sortable = sortable.reject do |stmt|
        key = stmt.normalized_key
        if seen[key]
          true # Remove this duplicate
        else
          seen[key] = true
          false # Keep this one
        end
      end

      # If no skipped statements, just use the sorted list
      if skipped_with_positions.empty?
        @statements = sortable
        return self
      end

      # Re-insert skipped statements at their original relative positions
      # We need to calculate where each skipped statement should go
      # in the new sorted list based on its original position ratio
      result = sortable.dup

      # Sort skipped statements by their original position
      skipped_with_positions.sort_by! { |s| s[:position] }

      # Insert each skipped statement
      skipped_with_positions.each_with_index do |skipped_info, skip_idx|
        original_pos = skipped_info[:position]
        original_count = @statements.size

        # Calculate the relative position in the new array
        if original_count <= 1
          insert_pos = skip_idx
        else
          # Scale the position to the new array size
          ratio = original_pos.to_f / (original_count - 1)
          new_max = result.size + skip_idx
          insert_pos = (ratio * new_max).round
        end

        # Clamp to valid range
        insert_pos = [[insert_pos, 0].max, result.size].min

        result.insert(insert_pos, skipped_info[:statement])
      end

      @statements = result
      self
    end

    # Convert the sorted block back to lines
    def to_lines
      return [] if @statements.empty?

      result = []

      # Add any leading content (comments before first import)
      result.concat(@leading_content) unless @leading_content.empty?

      # Group statements by section and type for proper spacing
      current_section = nil
      current_type = nil

      @statements.each do |stmt|
        # Filter out blank lines from the statement's leading comments
        # (we'll add our own spacing between groups)
        non_blank_comments = stmt.leading_comments.reject { |c| c.strip.empty? }

        # Add blank line between different sections (highest priority separator)
        if current_section && current_section != stmt.section && !result.empty?
          # Add blank line between sections (unless last line is already blank)
          unless result.last&.strip&.empty?
            result << "#{@indentation}\n"
          end
        # Add blank line between different import types within the same section
        elsif current_type && current_type != stmt.type && current_section == stmt.section && !result.empty?
          # Only add blank line if last line isn't already blank
          unless result.last&.strip&.empty?
            result << "#{@indentation}\n"
          end
        elsif current_type && current_type == stmt.type && non_blank_comments.any?
          # Same type but has comments - might need blank line before the comment
          # Only add if last line isn't blank
          unless result.last&.strip&.empty?
            result << "#{@indentation}\n" if stmt.leading_comments.any? { |c| c.strip.empty? }
          end
        end

        # Add non-blank leading comments
        non_blank_comments.each do |line|
          result << line
        end

        # Add the import line itself
        result << stmt.raw_line

        current_section = stmt.section
        current_type = stmt.type
      end

      result
    end

    # Calculate how many original lines this block spans
    def original_line_count
      return 0 if @start_line.nil? || @end_line.nil?

      @end_line - @start_line + 1
    end
  end
end
