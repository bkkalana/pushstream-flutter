library pushstream;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class PushStream {
  final String appKey;
  final String? appId;
  final String wsUrl;
  final String apiUrl;
  
  WebSocketChannel? _channel;
  String? _socketId;
  final Map<String, Channel> _channels = {};
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  bool _connected = false;
  StreamSubscription? _subscription;
  bool _shouldReconnect = true;

  PushStream(
    this.appKey, {
    this.appId,
    this.wsUrl = 'wss://ws.pushstream.ceylonitsolutions.online',
    this.apiUrl = 'https://api.pushstream.ceylonitsolutions.online',
  });

  Future<String?> connect() async {
    if (appId == null || appKey.isEmpty) {
      throw StateError('appId and appKey are required');
    }

    final completer = Completer<String?>();
    Timer? timeout;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl?app_id=$appId&app_key=$appKey'),
      );
      
      timeout = Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Connection timeout'));
          _attemptReconnect();
        }
      });
      
      _subscription = _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          
          if (data['event'] == 'pusher:connection_established') {
            final payload = jsonDecode(data['data']);
            _socketId = payload['socket_id'];
            _connected = true;
            _reconnectAttempts = 0;
            timeout?.cancel();
            print('[PushStream] Connected: $_socketId');
            if (!completer.isCompleted) completer.complete(_socketId);
          } else if (data['event'] == 'pusher:error') {
            print('[PushStream] Error: ${data['data']}');
          } else {
            _handleMessage(data);
          }
        },
        onError: (error) {
          print('[PushStream] Error: $error');
          timeout?.cancel();
          if (!completer.isCompleted) completer.completeError(error);
          if (_shouldReconnect) _attemptReconnect();
        },
        onDone: () {
          print('[PushStream] Disconnected');
          _connected = false;
          _socketId = null;
          timeout?.cancel();
          if (_shouldReconnect) _attemptReconnect();
        },
      );
    } catch (e) {
      print('[PushStream] Connection failed: $e');
      timeout?.cancel();
      if (!completer.isCompleted) completer.completeError(e);
      if (_shouldReconnect) _attemptReconnect();
    }

    return completer.future;
  }

  void _attemptReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('[PushStream] Max reconnection attempts reached');
      return;
    }

    final delay = Duration(
      milliseconds: (1000 * (1 << _reconnectAttempts)).clamp(0, 30000),
    );
    _reconnectAttempts++;

    print('[PushStream] Reconnecting in ${delay.inMilliseconds}ms (attempt $_reconnectAttempts)');
    Future.delayed(delay, () => connect());
  }

  Channel subscribe(String channelName) {
    if (!_connected) {
      throw StateError('Not connected');
    }
    
    final channel = Channel(channelName, this);
    _channels[channelName] = channel;
    
    _send({
      'event': 'pusher:subscribe',
      'data': {'channel': channelName},
    });

    return channel;
  }

  void unsubscribe(String channelName) {
    _send({
      'event': 'pusher:unsubscribe',
      'data': {'channel': channelName},
    });
    _channels.remove(channelName);
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null && _connected) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    final channelName = message['channel'];
    final channel = _channels[channelName];
    
    if (channel != null) {
      final event = message['event'];
      final data = jsonDecode(message['data']);
      channel._handleEvent(event, data);
    }
  }

  void disconnect() {
    _shouldReconnect = false;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    _socketId = null;
  }

  Future<Map<String, dynamic>> publish(
    String appId,
    String appSecret,
    String channel,
    String event,
    Map<String, dynamic> data,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final body = jsonEncode({
      'name': event,
      'channel': channel,
      'data': data,
    });
    
    final path = '/api/apps/$appId/events';
    final queryString = 'auth_timestamp=$timestamp';
    final stringToSign = 'POST\n$path\n$queryString\n$body';
    
    final signature = _hmacSha256(stringToSign, appSecret);
    final authHeader = '$appId:$signature';

    final response = await http.post(
      Uri.parse('$apiUrl$path?$queryString'),
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}: ${response.body}');
    }

    return jsonDecode(response.body);
  }

  String _hmacSha256(String message, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(message);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }

  String? get socketId => _socketId;
  bool get connected => _connected;
}

class Channel {
  final String name;
  final PushStream _client;
  final Map<String, List<Function(dynamic)>> _eventHandlers = {};

  Channel(this.name, this._client);

  Channel bind(String event, Function(dynamic) callback) {
    if (!_eventHandlers.containsKey(event)) {
      _eventHandlers[event] = [];
    }
    _eventHandlers[event]!.add(callback);
    return this;
  }

  Channel unbind(String event, [Function(dynamic)? callback]) {
    if (!_eventHandlers.containsKey(event)) return this;
    
    if (callback != null) {
      _eventHandlers[event]!.remove(callback);
    } else {
      _eventHandlers.remove(event);
    }
    return this;
  }

  void _handleEvent(String event, dynamic data) {
    final handlers = _eventHandlers[event];
    if (handlers != null) {
      for (var handler in handlers) {
        handler(data);
      }
    }
  }

  void unsubscribe() {
    _client.unsubscribe(name);
  }
}
