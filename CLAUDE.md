# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

SwiftClaude is a Swift client library for Anthropic's Claude API, supporting macOS 15+, iOS 18+, watchOS 11+, tvOS 18+, and visionOS 2+. The project uses Swift 6 with strict concurrency and is organized as a Swift Package.

## Commands

### Build & Test
```bash
# Build the project
swift build

# Run tests
swift test

# Run a specific test
swift test --filter TestName

# Clean build artifacts
swift package clean
```

## Architecture

### Module Structure
The codebase is organized into focused modules. Only pay attention to the modules listed here (the others have significant changes in flight):

- **Schema Coding**: JSON schema encoding/decoding infrastructure
- **JSON Support**: Custom JSON parsing and encoding

## Important Notes

1. **Swift 6 Required**: The project requires Swift 6 with upcoming features enabled
2. **Strict Concurrency**: Uses `isolated` actors and `@Sendable` throughout
5. **Testing Framework**: Uses Swift Testing (not XCTest) for all tests
6. **Platform Support**: Works on all Apple platforms and Linux via devcontainers