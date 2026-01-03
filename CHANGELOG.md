## [Released]

## [0.2.0] - 2026-01-03

Major rewrite with robust new architecture

### Added
- Complete architecture rewrite with modular components:
  - `Parser` class for line classification
  - `ImportStatement` class for import metadata
  - `ImportBlock` class for contiguous import groups
  - `FileProcessor` class for file orchestration
- Comprehensive duplicate import removal
- Proper handling of shebang and magic comments
- Support for all six import types: require, require_relative, include, extend, autoload, using
- Inline comment preservation
- Leading comment preservation (comments stay with their imports when sorted)
- Idempotent sorting (running multiple times produces same result)
- Proper encoding validation (UTF-8)
- Heredoc preservation
- Conditional import structure preservation
- Nested import sorting (inside classes/modules)
- Mixed quote style support
- Parenthesized require support
- 69 comprehensive unit tests covering edge cases

### Changed
- Imports are now grouped by type with blank lines between groups
- Multiple consecutive blank lines are normalized to single blank lines
- Better error messages for invalid files

### Fixed
- Comment handling no longer causes unexpected reordering
- Encoding errors are now properly detected and reported
- Files with no imports are left untouched
- Non-import code no longer breaks import sorting

## [0.1.3] - 2024-12-28

- Initial release

### Added
- Initial release
- Basic import sorting functionality
- Support for require, require_relative, include, and extend statements
- CLI interface
- Preservation of code structure and spacing

## [0.1.4] - 2024-12-29

- Second release

### Added
- Import sorting functionality support for a whole directory

## [0.1.5] - 2024-12-29

- Third release

### Added
- Preserve comments associated with imports
- Add new line between different groups sorted
- Don't do anything if no imports are found in a file
