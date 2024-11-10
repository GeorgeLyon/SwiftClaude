# Example Apps

These examples use the keychain to store your Anthropic API key.
This requires a provisioning profile, so if you are trying this at home you will need to sign in to your Apple developer account in Xcode Settings.
If you are trying to recreate this setup in your own project, you need to set up your provisioning rules correctly as well.
The easiest way to accomplish this is to add the "Keychain Sharing" capability to your project (you don't need to actually add any sharing groups, just adding the capability should provision your profile correctly.)

## Haiku Generator

The Haiku Generator example demonstrates using `SwiftClaude` to generate haikus and use tools.

## Computer Use Demo

The Computer Use Demo demonstrates Claude's ability to use computers.
