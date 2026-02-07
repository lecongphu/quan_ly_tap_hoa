import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Binding that patches accessibility announce messages on Windows.
///
/// Some Windows embedder builds expect `viewId` to be encoded as int64. The
/// default codec encodes small ints as int32, which can cause engine logs like:
/// "Announce message 'viewId' property must be a FlutterViewId."
class AccessibilityFixBinding extends WidgetsFlutterBinding {
  /// Ensures the binding is initialized.
  static WidgetsBinding ensureInitialized() {
    try {
      return WidgetsBinding.instance;
    } on FlutterError {
      AccessibilityFixBinding();
      return WidgetsBinding.instance;
    }
  }

  @override
  BinaryMessenger createBinaryMessenger() {
    final BinaryMessenger messenger = super.createBinaryMessenger();
    if (defaultTargetPlatform != TargetPlatform.windows) {
      return messenger;
    }
    return _AccessibilityBinaryMessenger(messenger);
  }
}

class _AccessibilityBinaryMessenger extends BinaryMessenger {
  _AccessibilityBinaryMessenger(this._delegate);

  final BinaryMessenger _delegate;
  static const StandardMessageCodec _standardCodec = StandardMessageCodec();
  static const _Int64StandardMessageCodec _int64Codec = _Int64StandardMessageCodec();

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    if (channel == SystemChannels.accessibility.name) {
      return _delegate.send(channel, _fixAccessibilityMessage(message));
    }
    return _delegate.send(channel, message);
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    _delegate.setMessageHandler(channel, handler);
  }

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    PlatformMessageResponseCallback? callback,
  ) {
    return _delegate.handlePlatformMessage(channel, data, callback);
  }

  ByteData? _fixAccessibilityMessage(ByteData? message) {
    if (message == null) {
      return null;
    }
    Object? decoded;
    try {
      decoded = _standardCodec.decodeMessage(message);
    } on FormatException {
      return message;
    }
    if (decoded is! Map) {
      return message;
    }
    if (decoded['type'] != 'announce') {
      return message;
    }
    final Object? data = decoded['data'];
    if (data is! Map) {
      return message;
    }
    if (data['viewId'] is! int) {
      return message;
    }
    return _int64Codec.encodeMessage(decoded);
  }
}

class _Int64StandardMessageCodec extends StandardMessageCodec {
  const _Int64StandardMessageCodec();

  static const int _valueInt64 = 4;

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value is int) {
      buffer.putUint8(_valueInt64);
      buffer.putInt64(value);
      return;
    }
    super.writeValue(buffer, value);
  }
}
