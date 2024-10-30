#if canImport(Security)

  public import Observation

  import Security
  import Foundation

  // MARK: - Implementation

  public typealias KeychainAuthenticator = ClaudeClient.KeychainAuthenticator

  extension ClaudeClient.Authenticator where Self == ClaudeClient.KeychainAuthenticator {

    @MainActor
    public static func keychain(
      namespace: String,
      identifier: String,
      useDataProtectionKeychain: Bool = true
    ) -> Self {
      ClaudeClient.KeychainAuthenticator(
        namespace: namespace, identifier: identifier,
        useDataProtectionKeychain: useDataProtectionKeychain)
    }

  }

  extension ClaudeClient {

    /**
     While this class is `Observable`, it will only signal a change if it is the object used to make the change.
     There is no way to observe the keychain generally.
     */
    @MainActor
    @Observable
    public final class KeychainAuthenticator: ClaudeClient.Authenticator, Sendable {

      public protocol ErrorReporter {
        func report(_ error: Error)
      }

      /// - Parameters:
      ///   - namespace:
      ///       A prefix representing associated API keys.
      ///   - identifier:
      ///       A unique identifier under which API keys will be stored
      ///   - useDataProtectionKeychain:
      ///       See https://developer.apple.com/documentation/security/ksecusedataprotectionkeychain
      ///       Setting this to `false` is discouraged and only available on `macOS`.
      ///       Using the data protection keychain requires a provisioning profile, and in cases where this isn't possible we still prefer users use the keychain to store API keys.
      public init(
        namespace: String,
        identifier: String,
        useDataProtectionKeychain: Bool = true
      ) {
        guard !identifier.isEmpty else {
          fatalError()
        }
        #if !os(macOS)
          /// On non-macOS platforms, there is only the data protection keychain
          assert(useDataProtectionKeychain)
        #endif
        self.namespace = namespace
        self.identifier = identifier
        self.store = KeychainStore(
          account: [Self.accountPrefix, namespace, ".", identifier, Self.accountSuffix].joined(),
          useDataProtectionKeychain: useDataProtectionKeychain
        )
        do {
          if let password = try store.savedPassword {
            authenticationState = .authenticated(
              summary: try APIKey.deserialize(password).description
            )
          } else {
            authenticationState = .unauthenticated
          }
        } catch {
          authenticationState = .failed(error)
        }
      }

      /// The current authentication state of this `KeychainAuthenticator`.
      /// While `KeychainAuthenticator` is `Observable`, this will only update for operations on this instance of `KeychainAuthenticator`.
      public private(set) var authenticationState: AuthenticationState
      public enum AuthenticationState {
        case authenticated(summary: String)
        case unauthenticated
        case failed(Error)
      }

      public nonisolated var apiKey: ClaudeClient.APIKey? {
        get throws {
          guard let password = try store.savedPassword else {
            return nil
          }
          return try .deserialize(password)
        }
      }

      public func save(_ apiKey: ClaudeClient.APIKey) throws {
        do {
          try store.save(Data(apiKey.serialized))
          authenticationState = .authenticated(summary: apiKey.description)
        } catch {
          authenticationState = .failed(error)
        }
      }

      @discardableResult
      public func deleteApiKey() throws -> Bool {
        do {
          authenticationState = .unauthenticated
          return try store.deletePassword()
        } catch {
          authenticationState = .failed(error)
          throw error
        }
      }

      /// Only works for keys stored in the data protection keychain
      public static func allAuthenticatorsWithSavedKeys(
        in namespace: String,
        errorReporter: ErrorReporter
      ) throws -> [KeychainAuthenticator] {
        try KeychainStore.listStoresInDataProtectionKeychain(
          withPrefix: accountPrefix,
          suffix: accountSuffix
        ).compactMap { store -> KeychainAuthenticator? in
          do {
            guard
              store.account.hasPrefix(accountPrefix),
              store.account.hasSuffix(accountSuffix)
            else {
              throw InvalidAccountError(account: store.account)
            }
            let identifierAndNamespace = store.account
              .dropFirst(accountPrefix.count)
              .dropLast(accountSuffix.count)
            guard !identifierAndNamespace.isEmpty else {
              throw InvalidAccountError(account: store.account)
            }
            guard
              identifierAndNamespace.hasPrefix("\(namespace).")
            else {
              /// This identifier is in a different namespace
              return nil
            }

            let authenticator = KeychainAuthenticator(
              namespace: namespace,
              identifier: String(identifierAndNamespace.dropFirst(namespace.count + 1))
            )
            guard authenticator.store.account == store.account else {
              throw InvalidAccountError(account: store.account)
            }
            return authenticator
          } catch {
            assertionFailure()
            errorReporter.report(error)
            do {
              try store.deletePassword()
            } catch {
              errorReporter.report(error)
            }
            return nil
          }
        }
      }

      public static func deleteAllSavedKeys() throws {
        let stores = try KeychainStore.listStoresInDataProtectionKeychain(
          withPrefix: accountPrefix,
          suffix: accountSuffix
        )
        let results = stores.map { store in
          Result {
            try store.deletePassword()
          }
        }
        for result in results {
          _ = try result.get()
        }
      }

      public let namespace: String
      public let identifier: String

      private func apiKeyDidChange() {
        generation += 1
      }
      private var generation = 0

      private static nonisolated let accountPrefix: String = "\(bundleIdentifier)."
      private static nonisolated let accountSuffix: String = ".swift-claude.api-key"
      private static nonisolated let bundleIdentifier: String =
        Bundle.main.bundleIdentifier ?? "com.anthropic.unspecified-third-party"

      private let store: KeychainStore

      private struct InvalidAccountError: Error {
        let account: String
      }
    }

    // MARK: - Keychain Store

    private struct KeychainStore: Sendable {

      init(
        account: String,
        useDataProtectionKeychain: Bool
      ) {
        self.account = account
        self.sharedQueryKeyValuePairs = .init(
          keyValuePairs: [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true,
          ]
        )
      }

      func save(
        _ password: Data,
        overwritePreviousValueIfOneExists: Bool = true
      ) throws {
        let result = SecItemAdd(
          query(additionalKeyValuePairs: [
            kSecValueData: password
          ]),
          nil
        )
        switch result {
        case errSecSuccess:
          break
        case errSecDuplicateItem where overwritePreviousValueIfOneExists:
          try deletePassword()
          try save(password, overwritePreviousValueIfOneExists: false)
        case let result:
          throw Error.itemAddFailure(result)
        }
      }

      var savedPassword: Data? {
        get throws {
          var data: CFTypeRef?
          let result = SecItemCopyMatching(
            query(additionalKeyValuePairs: [
              kSecReturnData: true,
              kSecMatchLimitOne: true,
            ]),
            &data
          )
          switch result {
          case errSecSuccess:
            guard let data = data as? Data else {
              throw Error.didNotReceiveData(type(of: data))
            }
            return data
          case errSecItemNotFound:
            return nil
          case let result:
            throw Error.itemCopyMatchingFailure(result)
          }
        }
      }

      func restorePassword() throws -> Data {
        guard let credential = try savedPassword else {
          throw Error.credentialNotFound
        }
        return credential
      }

      @discardableResult
      func deletePassword() throws -> Bool {
        try Self.deleteItems(query())
      }

      static func listStoresInDataProtectionKeychain(
        withPrefix prefix: String,
        suffix: String
      ) throws -> [KeychainStore] {
        var values: CFTypeRef?
        let result = SecItemCopyMatching(
          [
            kSecClass: kSecClassGenericPassword,
            kSecUseDataProtectionKeychain: true,
            kSecReturnAttributes: true,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitAll,
          ] as CFDictionary,
          &values
        )
        switch result {
        case errSecSuccess:
          guard let values = values as? [[CFString: Any]] else {
            throw Error.didNotReceiveArray(type(of: values))
          }
          return values.compactMap { value in
            guard let account = value[kSecAttrAccount] as? String else {
              return nil
            }
            guard account.hasPrefix(prefix), account.hasSuffix(suffix) else {
              return nil
            }
            return KeychainStore(account: account, useDataProtectionKeychain: true)
          }
        case errSecItemNotFound:
          return []
        case let result:
          throw Error.itemCopyMatchingFailure(result)
        }
      }

      let account: String

      /// - returns: `true` if the item was deleted, `false` if it was not found.
      private static func deleteItems(_ query: CFDictionary) throws -> Bool {
        let result = SecItemDelete(query)
        switch result {
        case errSecSuccess:
          return true
        case errSecItemNotFound:
          return false
        case let result:
          throw Error.itemDeleteFailure(result)
        }
      }

      private func query(additionalKeyValuePairs: KeyValuePairs<CFString, Any> = [:])
        -> CFDictionary
      {
        [CFString: Any](
          uniqueKeysWithValues: [
            sharedQueryKeyValuePairs.keyValuePairs,
            additionalKeyValuePairs,
          ].joined().map { ($0.key, $0.value) }
        ) as CFDictionary
      }
      private struct QueryKeyValuePairs: @unchecked Sendable {
        /// Its safe to send these
        let keyValuePairs: KeyValuePairs<CFString, Any>
      }
      private let sharedQueryKeyValuePairs: QueryKeyValuePairs

      private enum Error: Swift.Error {
        case didNotReceiveData(Any.Type)
        case didNotReceiveArray(Any.Type)
        case itemCopyMatchingFailure(CInt)
        case itemDeleteFailure(CInt)
        case itemAddFailure(CInt)
        case credentialNotFound
      }
    }

  }

#endif
