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

import 'package:flutter/foundation.dart';
import 'package:splunk_otel_flutter/src/custom_tracking.dart';

/// Wires automatic error capture into [FlutterError.onError] and
/// [PlatformDispatcher.instance.onError].
///
/// Call once after the SDK is installed. Both hooks chain the previous
/// handler so existing error reporting is preserved.
void installErrorInstrumentation(CustomTracking customTracking) {
  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    customTracking.trackError(
      details.exception,
      stackTrace: details.stack ?? StackTrace.empty,
      handled: false,
    );
    previousFlutterOnError?.call(details);
  };

  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    customTracking.trackError(error, stackTrace: stack, handled: false);
    return previousPlatformOnError?.call(error, stack) ?? false;
  };
}
