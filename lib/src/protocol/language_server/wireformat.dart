import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';
import 'package:async/async.dart';

class StdIOStreamChannel extends StreamChannelMixin<String> {
  final StreamSink<String> sink;
  final Stream<String> stream;

  factory StdIOStreamChannel() {
    var outSink = new StreamSinkTransformer.fromHandlers(handleData: _serialize)
        .bind(stdout);
    var inStream = new _Parser().stream;
    return new StdIOStreamChannel._(inStream, outSink);
  }

  StdIOStreamChannel._(this.stream, this.sink);
}

void _serialize(String data, EventSink<List<int>> sink) {
  var message = UTF8.encode(data);
  var header = 'Content-Length:${message.length}\r\n\r\n';
  sink.add([]..addAll(ASCII.encode(header))..addAll(message));
}

class _Parser {
  final _streamCtl = new StreamController<String>();
  Stream<String> get stream => _streamCtl.stream;

  final _buffer = <int>[];
  bool _headerMode = true;
  int _contentLength = -1;

  _Parser() {
    stdin.lineMode = false;
    stdin.expand((bytes) => bytes).listen(_handleByte, onDone: () {
      _streamCtl.close();
    });
  }

  void _handleByte(int byte) {
    if (byte == 4) {
      _streamCtl.close();
      return;
    }
    _buffer.add(byte);
    if (_headerMode && _headerComplete) {
      _contentLength = _parseContentLength();
      _buffer.clear();
      _headerMode = false;
    } else if (!_headerMode && _messageComplete) {
      _streamCtl.add(UTF8.decode(_buffer));
      _buffer.clear();
      _headerMode = true;
    }
  }

  /// Whether the entire message is in [_buffer].
  bool get _messageComplete => _buffer.length >= _contentLength;

  /// Decodes [_buffer] into a String and looks for the 'Content-Length' header.
  int _parseContentLength() {
    var asString = ASCII.decode(_buffer);
    var headers = asString.split('\r\n');
    var lengthHeader =
        headers.firstWhere((h) => h.startsWith('Content-Length'));
    var length = lengthHeader.split(':').last.trim();
    return int.parse(length);
  }

  /// Whether [_buffer] ends in '\r\n\r\n'.
  bool get _headerComplete {
    var l = _buffer.length;
    return l > 4 &&
        _buffer[l - 1] == 10 &&
        _buffer[l - 2] == 13 &&
        _buffer[l - 3] == 10 &&
        _buffer[l - 4] == 13;
  }
}