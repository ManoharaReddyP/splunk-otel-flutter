/*
 * Copyright 2026 Splunk Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splunk_otel_flutter/splunk_otel_flutter.dart';
// ignore: implementation_imports
import 'package:splunk_otel_flutter/src/error_instrumentation.dart';
// ignore: implementation_imports
import 'package:splunk_otel_flutter_platform_interface/src/pigeon/messages.pigeon.dart';

const _trackErrorChannel =
    'dev.flutter.pigeon.splunk_otel_flutter_platform_interface'
    '.SplunkOtelFlutterHostApi.customTrackingTrackError';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  const channel = BasicMessageChannel<Object?>(
    _trackErrorChannel,
    SplunkOtelFlutterHostApi.pigeonChannelCodec,
  );

  late FlutterExceptionHandler? savedFlutterOnError;
  late ErrorCallback? savedPlatformOnError;
  late GeneratedError? received;

  setUp(() {
    received = null;
    savedFlutterOnError = FlutterError.onError;
    savedPlatformOnError = PlatformDispatcher.instance.onError;

    binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      channel,
      (message) async {
        received = (message! as List<Object?>)[0] as GeneratedError;
        return <Object?>[null];
      },
    );
  });

  tearDown(() {
    FlutterError.onError = savedFlutterOnError;
    PlatformDispatcher.instance.onError = savedPlatformOnError;
    binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      channel,
      null,
    );
  });

  group('installErrorInstrumentation - FlutterError.onError', () {
    test('reports exception as unhandled error span', () async {
      installErrorInstrumentation(SplunkRum.instance.customTracking);

      final exception = Exception('flutter widget error');
      final details = FlutterErrorDetails(exception: exception);
      FlutterError.onError!(details);

      await Future<void>.value();

      expect(received, isNotNull);
      expect(received!.message, contains('flutter widget error'));
      expect(received!.handled, isFalse);
    });

    test('includes stack trace from FlutterErrorDetails', () async {
      installErrorInstrumentation(SplunkRum.instance.customTracking);

      final stack = StackTrace.fromString('at test_frame 1:1');
      final details = FlutterErrorDetails(
        exception: Exception('err'),
        stack: stack,
      );
      FlutterError.onError!(details);

      await Future<void>.value();

      expect(received!.stacktrace, contains('test_frame'));
    });

    test('uses empty stack trace when FlutterErrorDetails.stack is null',
        () async {
      installErrorInstrumentation(SplunkRum.instance.customTracking);

      final details = FlutterErrorDetails(exception: Exception('no stack'));
      FlutterError.onError!(details);

      await Future<void>.value();

      expect(received, isNotNull);
    });

    test('chains the previous FlutterError.onError handler', () async {
      var previousCalled = false;
      FlutterError.onError = (_) {
        previousCalled = true;
      };

      installErrorInstrumentation(SplunkRum.instance.customTracking);

      FlutterError.onError!(FlutterErrorDetails(exception: Exception('chain')));

      await Future<void>.value();

      expect(previousCalled, isTrue);
    });

    test('does not throw when previous FlutterError.onError is null', () async {
      FlutterError.onError = null;
      installErrorInstrumentation(SplunkRum.instance.customTracking);

      expect(
        () => FlutterError.onError!(
          FlutterErrorDetails(exception: Exception('no prev')),
        ),
        returnsNormally,
      );
    });
  });

  group('installErrorInstrumentation - PlatformDispatcher.instance.onError', () {
    test('reports exception as unhandled error span', () async {
      installErrorInstrumentation(SplunkRum.instance.customTracking);

      final error = Exception('platform dispatch error');
      PlatformDispatcher.instance.onError!(error, StackTrace.empty);

      await Future<void>.value();

      expect(received, isNotNull);
      expect(received!.message, contains('platform dispatch error'));
      expect(received!.handled, isFalse);
    });

    test('includes stack trace', () async {
      installErrorInstrumentation(SplunkRum.instance.customTracking);

      final stack = StackTrace.fromString('at platform_frame 2:2');
      PlatformDispatcher.instance.onError!(Exception('err'), stack);

      await Future<void>.value();

      expect(received!.stacktrace, contains('platform_frame'));
    });

    test('chains previous handler and returns its result', () async {
      PlatformDispatcher.instance.onError = (e, st) => true;

      installErrorInstrumentation(SplunkRum.instance.customTracking);

      final result = PlatformDispatcher.instance.onError!(
        Exception('chain'),
        StackTrace.empty,
      );

      expect(result, isTrue);
    });

    test('returns false when no previous handler', () async {
      PlatformDispatcher.instance.onError = null;

      installErrorInstrumentation(SplunkRum.instance.customTracking);

      final result = PlatformDispatcher.instance.onError!(
        Exception('no prev'),
        StackTrace.empty,
      );

      expect(result, isFalse);
    });
  });
}
