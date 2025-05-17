# Example App

These examples use the keychain to store your Anthropic API key.
You can run the examples in the iOS Simulator without a developer account, but on macOS using the "data protection" keychain requires a provisioning profile (a less secure/ergonmic version of keychain is allowed on macOS without a provisioning profile, but we do not recommend using it).
For provisioning to work correctly on macOS, you will need to sign into an Apple developer account in Xcode Settings.
If you are trying to recreate this setup in your own project, you need to set up your provisioning rules correctly as well.
The easiest way to accomplish this is to add the "Keychain Sharing" capability to your project (you don't need to actually add any sharing groups, just adding the capability should configure your provisioning profile correctly.)

## Haiku Generator

The Haiku Generator example demonstrates using `SwiftClaude` to generate haikus and use tools.
