import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:security_gate/security_gate.dart';

// ---------------------------------------------------------------------------
// Mock checks for testing
// ---------------------------------------------------------------------------

/// A mock check that always passes.
class _PassingCheck extends SecurityCheck {
  final String _name;
  final Duration _delay;

  _PassingCheck({String name = 'Passing Check', Duration? delay})
      : _name = name,
        _delay = delay ?? const Duration(milliseconds: 10);

  @override
  String get name => _name;

  @override
  Future<CheckResult> execute() async {
    await Future<void>.delayed(_delay);
    return CheckResult.pass(checkName: name);
  }
}

/// A mock check that always fails.
class _FailingCheck extends SecurityCheck {
  final String _name;
  final FailureAction _action;

  _FailingCheck({
    String name = 'Failing Check',
    FailureAction action = FailureAction.dialog,
  })  : _name = name,
        _action = action;

  @override
  String get name => _name;

  @override
  Future<CheckResult> execute() async {
    return CheckResult.fail(
      checkName: name,
      reason: '$name failed.',
      action: _action,
    );
  }
}

/// A mock check that never completes (to test timeout).
class _HangingCheck extends SecurityCheck {
  @override
  String get name => 'Hanging Check';

  @override
  Duration get timeout => const Duration(milliseconds: 100);

  @override
  Future<CheckResult> execute() async {
    // Never completes — simulates a check that hangs forever.
    await Completer<void>().future;
    return CheckResult.pass(checkName: name); // unreachable
  }
}

/// A mock check that throws an exception.
class _ThrowingCheck extends SecurityCheck {
  @override
  String get name => 'Throwing Check';

  @override
  Future<CheckResult> execute() async {
    throw StateError('Something went terribly wrong');
  }
}

/// A mock check that fails N times then passes (to test retry).
class _EventuallyPassingCheck extends SecurityCheck {
  final int _failuresBeforePass;
  int _attempts = 0;

  _EventuallyPassingCheck({int failuresBeforePass = 2})
      : _failuresBeforePass = failuresBeforePass;

  @override
  String get name => 'Eventually Passing Check';

  @override
  RetryPolicy? get retryPolicy => const RetryPolicy(
        maxAttempts: 3,
        backoff: Duration(milliseconds: 50),
        backoffMultiplier: 1.0, // Constant backoff for predictable tests
      );

  int get attempts => _attempts;

  @override
  Future<CheckResult> execute() async {
    _attempts++;
    if (_attempts <= _failuresBeforePass) {
      return CheckResult.fail(
        checkName: name,
        reason: 'Attempt $_attempts failed.',
        action: FailureAction.retry,
      );
    }
    return CheckResult.pass(checkName: name);
  }
}

/// A silent logger that records messages for assertion.
class _TestLogger implements SecurityLogger {
  final List<String> messages = [];

  @override
  void log(String message, {LogLevel level = LogLevel.info}) {
    messages.add('[${level.name}] $message');
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CheckResult', () {
    test('pass factory creates a passing result', () {
      final result = CheckResult.pass(checkName: 'Test');
      expect(result.passed, isTrue);
      expect(result.failureReason, isNull);
      expect(result.checkName, 'Test');
    });

    test('fail factory creates a failing result', () {
      final result = CheckResult.fail(
        checkName: 'Test',
        reason: 'Bad things happened',
        action: FailureAction.forceExit,
      );
      expect(result.passed, isFalse);
      expect(result.failureReason, 'Bad things happened');
      expect(result.failureAction, FailureAction.forceExit);
    });

    test('timeout factory creates a timeout result', () {
      final result = CheckResult.timeout(
        checkName: 'Slow Check',
        timeoutDuration: const Duration(seconds: 15),
      );
      expect(result.passed, isFalse);
      expect(result.failureReason, contains('timed out'));
      expect(result.failureReason, contains('15s'));
      expect(result.failureAction, FailureAction.retry);
    });

    test('isA and getCheck identify underlying check type-safely', () {
      final check = _FailingCheck(name: 'Type Check');
      final result = CheckResult.fail(
        checkName: check.name,
        check: check,
        reason: 'Failed',
      );

      expect(result.isA<_FailingCheck>(), isTrue);
      expect(result.isA<_PassingCheck>(), isFalse);
      expect(result.getCheck<_FailingCheck>(), same(check));
      expect(result.getCheck<_PassingCheck>(), isNull);
    });
  });

  group('RetryPolicy', () {
    test('backoffForAttempt calculates exponential backoff', () {
      const policy = RetryPolicy(
        backoff: Duration(milliseconds: 100),
        backoffMultiplier: 2.0,
      );
      // attempt 0 = 100ms * 2^0 = 100ms (base)
      expect(policy.backoffForAttempt(0), const Duration(milliseconds: 100));
      // attempt 1 = 100ms * 2.0 = 200ms
      expect(policy.backoffForAttempt(1), const Duration(milliseconds: 200));
      // attempt 2 = 100ms * 2.0 * 2.0 = 400ms
      expect(policy.backoffForAttempt(2), const Duration(milliseconds: 400));
    });

    test('backoffForAttempt with multiplier 1.0 gives constant backoff', () {
      const policy = RetryPolicy(
        backoff: Duration(milliseconds: 200),
        backoffMultiplier: 1.0,
      );
      expect(policy.backoffForAttempt(0), const Duration(milliseconds: 200));
      expect(policy.backoffForAttempt(1), const Duration(milliseconds: 200));
      expect(policy.backoffForAttempt(2), const Duration(milliseconds: 200));
    });
  });

  group('PipelineResult', () {
    test('failedCheck returns null when all passed', () {
      final result = PipelineResult(
        passed: true,
        results: [
          CheckResult.pass(checkName: 'A'),
          CheckResult.pass(checkName: 'B'),
        ],
        totalElapsed: const Duration(milliseconds: 100),
      );
      expect(result.failedCheck, isNull);
      expect(result.checksExecuted, 2);
      expect(result.checksPassed, 2);
    });

    test('failedCheck returns first failure', () {
      final result = PipelineResult(
        passed: false,
        results: [
          CheckResult.pass(checkName: 'A'),
          CheckResult.fail(checkName: 'B', reason: 'nope'),
        ],
        totalElapsed: const Duration(milliseconds: 200),
      );
      expect(result.failedCheck, isNotNull);
      expect(result.failedCheck!.checkName, 'B');
      expect(result.checksPassed, 1);
    });
  });

  group('SecurityPipeline', () {
    test('all checks pass → PipelineResult.passed is true', () async {
      final pipeline = SecurityPipeline(
        checks: [
          _PassingCheck(name: 'Check A'),
          _PassingCheck(name: 'Check B'),
          _PassingCheck(name: 'Check C'),
        ],
        logger: _TestLogger(),
      );

      final result = await pipeline.execute();

      expect(result.passed, isTrue);
      expect(result.results.length, 3);
      expect(result.results.every((r) => r.passed), isTrue);
      expect(result.failedCheck, isNull);
    });

    test('stops on first failure and preserves check instance for pattern matching', () async {
      final failingCheck = _FailingCheck(name: 'Check B');
      final pipeline = SecurityPipeline(
        checks: [
          _PassingCheck(name: 'Check A'),
          failingCheck,
          _PassingCheck(name: 'Check C'), // Should NOT run
        ],
        logger: _TestLogger(),
      );

      final result = await pipeline.execute();

      expect(result.passed, isFalse);
      expect(result.results.length, 2); // Only A and B
      expect(result.results[0].passed, isTrue);
      expect(result.results[1].passed, isFalse);
      expect(result.failedCheck!.checkName, 'Check B');
      expect(result.failedCheck!.check, same(failingCheck));
      expect(result.failedCheck!.isA<_FailingCheck>(), isTrue);

      // Verify Dart pattern matching works cleanly
      String matchedType = '';
      switch (result.failedCheck!.check) {
        case _PassingCheck():
          matchedType = 'passing';
        case _FailingCheck():
          matchedType = 'failing';
        default:
          matchedType = 'unknown';
      }
      expect(matchedType, 'failing');
    });

    test('handles timeout correctly', () async {
      final pipeline = SecurityPipeline(
        checks: [_HangingCheck()],
        logger: _TestLogger(),
      );

      final result = await pipeline.execute();

      expect(result.passed, isFalse);
      expect(result.results.length, 1);
      expect(result.results[0].passed, isFalse);
      expect(result.results[0].failureReason, contains('timed out'));
    });

    test('handles thrown exceptions gracefully', () async {
      final pipeline = SecurityPipeline(
        checks: [_ThrowingCheck()],
        logger: _TestLogger(),
      );

      final result = await pipeline.execute();

      expect(result.passed, isFalse);
      expect(result.results.length, 1);
      expect(result.results[0].failureReason, contains('Unhandled exception'));
    });

    test('retries with backoff then passes', () async {
      final check = _EventuallyPassingCheck(failuresBeforePass: 2);
      final logger = _TestLogger();

      final pipeline = SecurityPipeline(
        checks: [check],
        logger: logger,
      );

      final result = await pipeline.execute();

      expect(result.passed, isTrue);
      expect(check.attempts, 3); // 2 failures + 1 success
      // Verify retry log messages
      expect(
        logger.messages.any((m) => m.contains('Retrying')),
        isTrue,
      );
    });

    test('exhausts retries and fails', () async {
      // Fails 4 times, but retry policy only allows 3 retries (4 total attempts)
      final check = _EventuallyPassingCheck(failuresBeforePass: 10);
      final pipeline = SecurityPipeline(
        checks: [check],
        logger: _TestLogger(),
      );

      final result = await pipeline.execute();

      expect(result.passed, isFalse);
      expect(check.attempts, 4); // 1 initial + 3 retries
    });

    test('callbacks fire in correct order', () async {
      final events = <String>[];

      final pipeline = SecurityPipeline(
        checks: [
          _PassingCheck(name: 'Check A'),
          _FailingCheck(name: 'Check B'),
        ],
        logger: _TestLogger(),
        onCheckStart: (check) => events.add('start:${check.name}'),
        onCheckPassed: (check, _) => events.add('passed:${check.name}'),
        onCheckFailed: (check, _) => events.add('failed:${check.name}'),
        onPipelineComplete: (result) => events.add(
          'complete:${result.passed}',
        ),
      );

      await pipeline.execute();

      expect(events, [
        'start:Check A',
        'passed:Check A',
        'start:Check B',
        'failed:Check B',
        'complete:false',
      ]);
    });

    test('onPipelineComplete fires with passed=true when all pass', () async {
      PipelineResult? capturedResult;

      final pipeline = SecurityPipeline(
        checks: [
          _PassingCheck(name: 'A'),
          _PassingCheck(name: 'B'),
        ],
        logger: _TestLogger(),
        onPipelineComplete: (result) => capturedResult = result,
      );

      await pipeline.execute();

      expect(capturedResult, isNotNull);
      expect(capturedResult!.passed, isTrue);
    });

    test('empty pipeline passes immediately', () async {
      final pipeline = SecurityPipeline(
        checks: [],
        logger: _TestLogger(),
      );

      final result = await pipeline.execute();

      expect(result.passed, isTrue);
      expect(result.results, isEmpty);
    });

    test('logger receives all messages', () async {
      final logger = _TestLogger();
      final pipeline = SecurityPipeline(
        checks: [_PassingCheck(name: 'Logged Check')],
        logger: logger,
      );

      await pipeline.execute();

      expect(logger.messages, isNotEmpty);
      expect(
        logger.messages.any((m) => m.contains('Logged Check')),
        isTrue,
      );
      expect(
        logger.messages.any((m) => m.contains('passed')),
        isTrue,
      );
    });
  });
}
