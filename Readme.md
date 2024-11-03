# SwiftClaude

SwiftClaude is a Swift client for [Anthropic's Claude API](https://www.anthropic.com/api).

## Legal Disclaimer

CLAUDE and ANTHROPIC are trademarks of Anthropic, PBC. 
This project is not affiliated with or sponsored by Anthropic.

## Maturity

This package is very new and under-tested.
SwiftClaude is pre-1.0, meaning the API can change based on feedback from the community.

## Usage

### Basic Usage

The following examples assume you have created a value `let claude: Claude`. 
See [Authentication](#Authentication) for how to create a `Claude`. 

To send a message, you simply call `Claude.nextMessage`:
```swift
let message = claude.nextMessage(
  in: Converation {
    "Write me a haiku about a really well-made tool."
  }
)
```

Text-only messages can be processed in a number of ways.
The simplest is just getting the full text:
```swift
let text = try await message.text()
```

You can also stream text fragments as they arrive:
```swift
for try await fragment in message.textFragments {
  print(text, terminator: "")
  fflush(stdout)
}
print()
```

Messages are also `Observable` for easy integration with SwiftUI.
Properties meant to be observed are prefixed with `current`, such as `currentText`.
The `HaikuGenerator` example shows off how to use messages with SwiftUI.

## Tool Use

SwiftClaude has great support for [tool use](https://docs.anthropic.com/en/docs/build-with-claude/tool-use) via the `@Tool` macro. 

Here is an example tool definition:
```swift
@Tool
struct TurboEncabulator {

  /// Turbo-encabulates its input
  /// - Parameters:
  ///   - marzlevaneCount: the number of marzlevanes to use when turbo-encabulating
  func invoke(
    marzlevaneCount: Int
  ) {
    …
  }

}
```

Now, when this tool is provided to Claude, Claude will know how to call it.
The comment on the `invoke` function will also be sent to Claude to help Claude understand how to use the tool.

To provide tools to claude, just add the `tools:` argument when creating a message:
```swift
let message = claude.nextMessage(
  in: Conversation {
    "I'm creating a demo showcasing your ability to use tools, can you invoke the `TurboEncabulator` tool with some made-up input?"
  },
  tools: Tools {
    TurboEncabulator()
  }
)
```
_Note:_ `nextMessage` returns a different type depending on whether or not tools are provided. 
Without tools, you get a `StreamingTextMessage`, and with tools you get a `StreamingMessage<ToolOutput>`

By default, you need to manually request the invocation of any tools in the returned message by calling `requestInvocation` on the relevant content blocks, or `requestToolInvocations` on the message:
```swift
/// On individual content blocks
for try await block in message.contentBlocks {
  block.toolUseBlock?.requestInvocation()
}
/// On the message
message.requestToolInvocations()
```
You can also specify that SwiftClaude should automatically invoke tools when they are ready using `invokeTools: .whenInputAvailable`:
```swift
let message = claude.nextMessage(
  in: Conversation {
    "I'm creating a demo showcasing your ability to use tools, can you invoke the `TurboEncabulator` tool with some made-up input?"
  },
  tools: Tools {
    TurboEncabulator()
  },
  invokeTools: .whenInputAvailable
)
```

_Note:_ By default, Claude can request multiple parallel tool invocations. 
You can control this behavior by specifying a `ToolChoice` with `isParallelToolUseDisabled: false`.

More complex tools can be defined by providing custom `struct`s or `enum`s as arguments using the `@ToolInput` macro:
```swift
@ToolInput
enum SpurvingBearing {
  case fixed
  case rotating(rpm: Double)
  case magnetoReluctance(fieldStrength: Float, coilWindings: Int, fluxCapacitance: Double)
}

@Tool
private struct TurboEncabulator {

  /// Turbo-encabulates its input
  /// - Parameters:
  ///   - marzlevaneCount: the number of marzlevanes to use
  ///   - spurvingBearing: the type of Spurving bearing to use
  private func invoke(
    marzlevaneCount: Int,
    spurvingBearing: SpurvingBearing
  ) {
    
  }

}
```

## Vision

SwiftClaude supports [vision](https://docs.anthropic.com/en/docs/build-with-claude/vision).
On Apple platforms, you can include `UIImage`s and `NSImage`s directly in user messages:
```swift
let message = claude.nextMessage(
  in: Conversation {
    "Write me a haiku inspired by this image: \(image)"
  }
)
```

By default, SwiftClaude resizes images [per Anthropic's recommendations](https://docs.anthropic.com/en/docs/build-with-claude/vision#evaluate-image-size).
You can disable this behavior by specifying `imagePreprocessingMode: .disabled`.

## Prompt Caching (Beta)

SwiftClaude supports [prompt caching](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching).
You can add `Claude.Beta.CacheBreakpoint` to most result-builder APIs.
You can also add a `cacheBreakpoint: Claude.Beta.CacheBreakpoint()` parameter to string interpolations or `append` APIs.

## Authentication

⚠️
**You should take great care to keep your API keys private.**
**In no circumstances should you ship an application with your API key embedded.**
**Failure to keep your keys private could result in unexpected charges, rate limiting or other consequences.**

Authenticating with the Claude API via SwiftClaude requires using a `Claude.Authenticator`.
On Apple platforms, you are encouraged to use `KeychainAuthenticator` which stores API keys securely in the keychain.
```swift
let authenticator = Claude.KeychainAuthenticator(
  namespace: "com.codebygeorge.SwiftClaude.HaikuGenerator",
  identifier: "api-key"
)
/// Call `authenticator.save(…)` with your API key 
```

Once you have an authenticator, you can create a `Claude`:
```swift
let claude = Claude(authenticator: authenticator)
```

## Setup

SwiftClaude requires Swift 6 and macOS 15 or iOS 18.

`SwiftClaude` is built using Swift Package Manager.
To include it, add the following in your `Package.swift`
```swift
let package = Package(
  …
  dependencies: [
    .package(url: "git@github.com:GeorgeLyon/SwiftClaude", branch: "main")
  ],
  …
)
```

Then, add `SwiftClaude` as a dependency to your target:
```swift
    .target(
      …
      dependencies: [
        "SwiftClaude"
      ],
      …
    ),
```

You can also reference the projects in `Examples` for additional details.
