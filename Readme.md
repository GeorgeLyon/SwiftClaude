# SwiftClaude

SwiftClaude is a Swift client for [Anthropic's Claude API](https://www.anthropic.com/api).

## Legal Disclaimer

CLAUDE and ANTHROPIC are trademarks of Anthropic, PBC. 
This project is not affiliated with or sponsored by Anthropic.

## Maturity

This package is very new and under-tested.
SwiftClaude is pre-1.0, meaning the API can change based on feedback from the community.

## Usage

The following is a quick introduction to SwiftClaude.
For more details, look at the example projects defined in `.xcode/SwiftClaudeAppPackage`, particularly `HaikuGenerator`.

### Basic Usage

The following examples assume you have created a value `let claude: Claude`. 
See [Authentication](#Authentication) for how to create a `Claude`. 

SwiftClaude's core abstraction is `Conversation`, which is a protocol you implement in your project:
```swift
import SwiftClaude

struct Conversation: Claude.Conversation {
  var messages: [Message]
}

var conversation = Conversation(
  messages: [
    .user("Write me a haiku about a really well-made tool.")
  ]
)
```

Once you have a conversation, you can ask Claude to provide the next message:
```swift
let message = claude.nextMessage(in: conversation)
```

Messages have a simple async API, you can await the full text or process it in chunks:
```swift
/// Print the full text
print(try await message.text())

/// Print the text as segments come in
for try await segment in message.textSegments {
  print(segment, terminator: "")
  fflush(stdout)
}
print()
```

Messages are also `Observable`, meaning you can use them directly in SwiftUI:
```swift
Text(message.currentText)
```

For most properties, SwiftClaude provides an async version and an `Observable` version.
The `Observable` version is typically prefixed with `current`.

If you want to implement multiple turns of a conversation simply add the new message to the conversation followed by a response and request a new message.
```swift
conversation.messages += [
  .assistant(message),
  .user("That was great! Can you write me one more, this time about track saws?")
]
let nextMessage = claude.nextMessage(in: conversation)
```

### Tool Use

SwiftClaude has excellent support for [tool use](https://docs.anthropic.com/en/docs/build-with-claude/tool-use) via the `@Tool` macro.

Defining a tool is as easy as creating a type with an `invoke` method and attaching the `@Tool` macro.
Here is an example from `HaikuGenerator`:
```swift
@Tool
struct EmojiTool {

  /// Displays an emoji
  /// Great for spicing up a haiku!
  func invoke(
    _ emoji: String
  ) -> String {
    emoji
  }

}
```

The comment on the `invoke` function is particularly important here and SwiftClaude will actually send it to Claude to help Claude understand how best to call the function you define.
For information on how best to document your tool, consult [Anthropic's documentation](https://docs.anthropic.com/en/docs/build-with-claude/tool-use).

If you want the inputs to your tool to be more sophisticated, you can use the `@ToolInput` macro to define custom structs or enums.
For example, here is a `Command` tool that could enable claude to navigate forward, backward, or to a specified URL:
```swift
@ToolInput
enum Command {
  case goBack
  case goForward
  case navigate(to: String)
}
```

You can use this in a tool by simply adding it as parameter to the `invoke` function:
```swift
@Tool
struct Browser {

  /// Controls a browser
  func invoke(
    _ command: Command
  ) -> String {
    /// Execute `command`
  }

}
```

To use this in a conversation, you need to specify the type you want to use for `ToolOutput`:
```swift
private struct Conversation: Claude.Conversation {

  var messages: [Message] = []

  typealias ToolOutput = String

} 
```

`String` is the simplest type to use for tool output, but you can also use `ToolInvocationResultContent`, or even a custom type if you want to leverage more sophisticated capabilities like [vision](#Vision). 
For a working example, consult `ComputerUseDemo` in `.xcode/SwiftClaudeAppPackage`. 

You also need to provide Claude with the list of tools it has access to:
```swift
let message = claude.nextMessage(
  in: conversation,
  tools: Tools {
    CatEmojiTool()
    EmojiTool()
  }
)
```

When Claude requests tool invocations, those tools are not invoked by default and require explicitly calling `requestInvocation` on the specific tool, or `requestToolInvocations` on the message.
We recommend prompting the user before invoking tools to ensure that Claude's request is aligned with the user's intentions.
For simple tools which just provide context or display UI, you can specify a `ToolInvocationStrategy` that makes this process simpler.
For example `whenToolInputAvailable` will automatically invoke tools the input is decoded successfully:
```swift
let message = claude.nextMessage(
  in: conversation,
  tools: Tools {
    CatEmojiTool()
    EmojiTool()
  },
  invokeTools: .whenInputAvailable
) 
```

Conversations with tool use require handling some additional cases, since they may include more than just text.
Instead of just processing text or text segments, you will now need to process content blocks.
Text content blocks have a similar API to text-only messages, and tool use blocks can be processed in a number of ways.
The async API looks something like this:
```swift
for try await block in message.contentBlocks {
  switch block {
  case .textBlock(let textBlock):
    for try await textFragment in textBlock.textFragments {
      print(textFragment, terminator: "")
      fflush(stdout)
    }
  case .toolUseBlock(let toolUseBlock):
    print("[Using \(toolUseBlock.toolName): \(try await toolUseBlock.output())]")
  }
}
print()
```

Like text-only messages, messages with tool invocations are `Observable` and can be used in frameworks build on top of `Observation` like `SwiftUI` (via the `current`-prefixed properties).
Here is a SwiftUI example:
```swift
ForEach(assistant.currentContentBlocks) { block in
  switch block {
  case .textBlock(let textBlock):
    Text(textBlock.currentText)
  case .toolUseBlock(let toolUseBlock):
    if let output = toolUseBlock.toolUse.currentOutput {
      Text("[Using \(toolUseBlock.toolUse.toolName): \(output)]")
    } else {
      Text("[Using \(toolUseBlock.toolUse.toolName)]")
    }
  }
}
```

Note: Messages and content blocks also all conform to `Identifiable` to make it even easier to use with `SwiftUI`.

Tool results need to be sent back to Claude in order to continue the conversation. 
The easiest way to do this is to inspect `conversation.nextStep()` like so:
```swift
repeat {
  let message = claude.nextMessage(
    in: conversation, 
    tools: Tools { … }
  )
  conversation.append(message)
} while try await conversation.nextStep() == .toolUseResult
```

### Vision 

SwiftClaude supports [vision](https://docs.anthropic.com/en/docs/build-with-claude/vision).
On Apple platforms, you can include `UIImage` and `NSImage` directly in user messages:
```swift
conversation.messages.append(
  .user("Describe this image: \(image)")
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

You can also reference the projects in `.xcode/SwiftClaudeAppPackage` for additional details.
