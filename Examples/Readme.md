# SwiftClaude Examples

## Haiku Generator

The Haiku Generator example demonstrates using `SwiftClaude` with `KeychainAuthenticator`. 
Using the keychain requires a provisioning profile, so if you are trying this at home you will need to sign in to your Apple developer account in Xcode Settings.
If you are trying to recreate this setup in your own project, you need to set up your provisioning rules correctly as well.
The easiest way to accomplish this is to add the "Keychain Sharing" capability to your project (you don't need to actually add any sharing groups, just adding the capability should provision your profile correctly.)

## Computer Use

Currently this is macOS-only and doesn't perform too well, probably related to some issues with image resizing.
