# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands
- Build: `swift build`
- Test all: `swift test`
- Test single test: `swift test --filter "ToolTests.BoolSchemaTests/testSchemaEncoding"`
- Test specific suite: `swift test --filter "ToolTests.BoolSchemaTests"`
- List all tests: `swift test list`

## Code Style Guidelines
- Use PascalCase for types and protocols (e.g., `BoolSchema`, `LeafSchema`)
- Use camelCase for properties and methods (e.g., `primitiveRepresentation`)
- Group related functionality with `MARK: - Section Name` comments
- Follow protocol-oriented design with composition over inheritance
- Use extensions to add functionality to types
- Organize code in logical module structure with dedicated files for specific functionality
- Use Swift's type system features including generics and protocols
- Use Swift Testing framework with `@Suite`, `@Test` annotations
- Use `#expect` for assertions in tests
- Do not use `XCTest`
- Try to keep public APIs at the top of the file, followed by internal APIs, fileprivate APIs, and private APIs.
- Prefer optional chaining and conditional unwrapping over force unwrapping
- Use throwing functions for error handling
- Don't use `print` statements in tests
- Prefer using a single `expect` statement when validating strings in tests rather than multiple `expect` statements checking that the string `contains` certain values.
- While comments are useful (particularly for complex code), try to make what is happening apparent from the code through things like explicit naming.

## Requirements
- Run `swift format` after making changes to the code.
- Build the project and make sure any compiler warnings are addressed.
- When adding tests, add them one at a time and run each test after adding to ensure it passes.
