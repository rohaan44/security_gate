# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-09-02

### Added

- Core `SecurityCheck` abstract interface with `name`, `execute()`, `timeout`, and `retryPolicy`.
- `CheckResult` immutable result class with `pass`, `fail`, and `timeout` factory constructors.
- `FailureAction` enum: `silent`, `dialog`, `forceExit`, `retry`.
- `RetryPolicy` with configurable max attempts, backoff duration, and exponential backoff multiplier.
- `SecurityPipeline` runner with sequential execution, per-check timeouts, retry/backoff, and callbacks.
- `PipelineResult` aggregate result with `passed`, `failedCheck`, `results`, and `totalElapsed`.
- `SecurityLogger` pluggable logging interface with `DefaultLogger` print-based fallback.
- Built-in optional checks:
  - `JailbreakRootCheck` (stubbed — wire to detection package)
  - `PlayIntegrityCheck` (stubbed — wire to Play Integrity API)
  - `ProxyDetectionCheck` (environment variable inspection)
  - `BlockedNetworkCheck` (VPN tunnel + subnet blocklist detection)
  - `ThirdPartyKeyboardCheck` (stubbed — wire to platform channel)
  - `InternetWifiSecurityCheck` (DNS-based connectivity check)
- Example app with splash screen demonstrating full pipeline usage.
- Comprehensive unit tests for pipeline, results, retry, timeout, and callbacks.
- Android and iOS plugin shell classes for future platform channel integrations.
