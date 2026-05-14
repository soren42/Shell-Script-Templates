# Changelog

All notable changes to Shell Script Templates are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.0] - 2026-05-14

### Added
- **Feature Flag System**: 15+ configurable flags at the top of every script controlling execution requirements, capability toggles, and runtime validation
- **Initialization Wizard** (`init-script.sh`): Interactive script generation tool with shell selection, metadata collection, dependency analysis, argument specification, plugin selection, and test scaffolding
- **Plugin Architecture**: File-based plugin system with configuration, initialization, and function loading
- **Core Plugin: ai-integration**: Unified LLM API interface supporting Anthropic Claude, OpenAI GPT, and Google Gemini with provider switching, system prompts, and convenience functions
- **Core Plugin: http-client**: HTTP operations wrapper with retry logic, authentication (basic, bearer), file upload/download, and response helpers
- **Core Plugin: json-parser**: jq wrapper providing JSON reading, modification, validation, formatting, generation, and file operations
- **Core Plugin: tui**: Text User Interface abstraction supporting gum, dialog, whiptail, and pure ANSI fallback backends
- **Self-Test Framework**: Built-in `--self-test` flag with test function scaffolding and assertion helpers
- **Pre-flight Validation**: Automatic validation of root privileges, network connectivity, disk space, and execution environment based on feature flags
- **Script Porting**: `init-script.sh --port` flag to extract metadata from v1-v3 scripts and pre-populate v4 wizard
- **Non-Interactive Mode**: `--non-interactive` flag on init-script.sh for AI assistant and CI/CD pipeline integration
- **Standalone Test File Generation**: Wizard option to generate separate test files with assertion framework
- **JSON Metadata Block**: Machine-readable metadata appended to generated scripts for tooling integration

### Changed
- Templates restructured with feature flags section at top, before all other code
- Dependency validation now conditional on `HAS_EXTERNAL_DEPENDENCIES` flag
- Configuration loading now conditional on `USES_CONFIG_FILES` flag
- Version bumped to 4.0.0 across all files
- Documentation reorganized into `docs/` directory

### Improved
- All functions now include comprehensive documentation headers
- Variable naming consistently uses camelCase throughout
- Error messages include more context and actionable guidance

## [3.0.0] - 2026-01-24

### Added
- First public release
- Bash template with strict mode, logging, argument parsing, error handling
- Zsh template with zparseopts, TRAP functions, extended globbing, zcompile support
- Professional logging system with five verbosity levels and color support
- Hierarchical configuration file loading (7-level precedence)
- Dependency validation with `require_binary` and `optional_binary`
- Input validation helpers (integer, float, string, file, directory)
- Dry-run mode with `run()` wrapper
- Automatic temp file cleanup via trap/TRAP handlers
- BSD sysexits-compatible exit codes
- Comprehensive developer guides (README-bash.md, README-zsh.md)
- Complete API reference
- Multiple usage examples
- Bash vs Zsh comparison table

## [2.x] - Pre-release (Private)

### Summary
- Added argument parsing and dependency validation
- Configuration file support
- Improved error handling

## [1.x] - Pre-release (Private)

### Summary
- Initial implementations with basic error handling and logging
- Personal use templates

[4.0.0]: https://github.com/soren42/Shell-Script-Templates/releases/tag/v4.0.0
[3.0.0]: https://github.com/soren42/Shell-Script-Templates/releases/tag/v3.0.0
