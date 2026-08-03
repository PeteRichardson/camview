//
//  ConfigRule.swift
//  CamviewCore
//

import Foundation

/// The shape each config value must have, wherever it came from.
///
/// These live in `CamviewCore` rather than in the CLI because `camview config write` is
/// only one of three documented ways to set these values. `README.md` also documents
/// writing them directly:
///
/// ```sh
/// security add-generic-password -a api-key -s com.peterichardson.camview -w <key>
/// defaults write group.com.peterichardson.camview protect-host unvr.local
/// ```
///
/// Validating only on write leaves both of those unguarded, and the consequences are not
/// merely cosmetic — a host containing a space makes `URL(string:)` return nil, which the
/// `Protect` package force-unwraps, so camview exits 133 (SIGTRAP) printing nothing at
/// all. camgui dies the same way; a runtime trap isn't catchable by its `do`/`catch`.
///
/// Checking in ``Configuration/init(items:)`` covers every entry point at once, including
/// any added later, because that initializer is the single gate both products pass through.
public enum ConfigRule {
    /// Stated in the README, CLAUDE.md and docs/design.md; now also enforced.
    public static let apiKeyLength = 32

    /// The keys ``rejection(for:key:)`` actually checks.
    ///
    /// `configItems` lists the keys that *exist*; this lists the keys that get validated.
    /// A test asserts the two are identical, so adding a third config key fails rather
    /// than silently acquiring no validation — ``rejection(for:key:)`` accepts anything
    /// it has no rule for.
    public static let validatedKeys: Set<String> = ["api-key", "protect-host"]

    /// Why `value` is unacceptable for `key`, or `nil` if it's fine.
    ///
    /// Returns a reason rather than throwing so each caller can raise its own error type:
    /// the CLI wants ArgumentParser's `ValidationError` for a bad *argument*, while
    /// ``Configuration`` wants `ConfigError` for bad *stored state*.
    ///
    /// Deliberately strict about whitespace rather than trimming. Trimming is an input
    /// affordance that belongs to `config write`, which applies it before calling this; a
    /// value already in storage with stray whitespace is malformed, and saying so is more
    /// useful than silently repairing it on every read.
    public static func rejection(for value: String, key: String) -> String? {
        switch key {
        case "api-key":
            // Report the length, never the value. `config read` obfuscates this secret
            // deliberately, so an error message must not become the thing that prints it.
            guard value.count == apiKeyLength else {
                return "api-key must be exactly \(apiKeyLength) characters; got \(value.count). "
                    + "Generate one in Protect → Settings → Control Plane → Integrations."
            }

        case "protect-host":
            guard !value.isEmpty else {
                return "protect-host must not be empty. Give a hostname or IP address, "
                    + "e.g. unvr.local or 192.168.1.99."
            }
            guard !value.contains(where: \.isWhitespace) else {
                // The crash case: a space makes the request URL unparseable.
                return "protect-host must not contain whitespace. Give a hostname or IP "
                    + "address, e.g. unvr.local or 192.168.1.99."
            }
            guard !value.contains("/") else {
                // Catches a pasted `https://unvr.local`, which is otherwise accepted and
                // becomes `http://https://unvr.local/…` — a well-formed URL that fails DNS
                // with a 900-byte NSError naming nothing useful. A `/` cannot appear in a
                // hostname or IP, so this rejects a scheme or a path without guessing.
                // `:` stays legal: a non-default port is `unvr.local:7443`.
                return "protect-host must be a bare hostname or IP, with no scheme or path. "
                    + "Use unvr.local, not https://unvr.local."
            }

        default:
            // A key with no rule. Unreachable while `validatedKeys` and `configItems`
            // agree, which is asserted by a test rather than a fatalError here.
            break
        }

        return nil
    }
}
