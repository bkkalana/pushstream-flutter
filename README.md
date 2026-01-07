# PushStream Flutter SDK

Real-time messaging SDK for Flutter applications.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  pushstream:
    git:
      url: https://github.com/pushstream/pushstream-flutter.git
```

Or install from pub.dev (when published):

```yaml
dependencies:
  pushstream: ^1.0.0
```

## Usage

### Initialize

```dart
import 'package:pushstream/pushstream.dart';

final client = PushStream(
  'your-app-key',
  wsUrl: 'ws://localhost:3001',
  apiUrl: 'http://localhost:8000',
);
```

### Connect

```dart
try {
  final socketId = await client.connect();
  print('Connected: $socketId');
} catch (e) {
  print('Connection failed: $e');
}
```

### Subscribe to Channel

```dart
final channel = client.subscribe('orders');

channel.bind('order.created', (data) {
  print('New order: $data');
});
```

### Publish Event (Server-side)

```dart
await client.publish(
  'app-id',
  'app-secret',
  'orders',
  'order.created',
  {'order_id': 123, 'amount': 99.99},
);
```

### Unsubscribe

```dart
channel.unsubscribe();
// or
client.unsubscribe('orders');
```

### Disconnect

```dart
client.disconnect();
```

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:pushstream/pushstream.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late PushStream client;
  List<String> messages = [];

  @override
  void initState() {
    super.initState();
    _initPushStream();
  }

  Future<void> _initPushStream() async {
    client = PushStream('your-app-key');
    
    try {
      await client.connect();
      
      final channel = client.subscribe('notifications');
      channel.bind('new-message', (data) {
        setState(() {
          messages.add(data['message']);
        });
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('PushStream Demo')),
        body: ListView.builder(
          itemCount: messages.length,
          itemBuilder: (context, index) {
            return ListTile(title: Text(messages[index]));
          },
        ),
      ),
    );
  }
}
```

## Features

- ✅ WebSocket connection with auto-reconnect
- ✅ Exponential backoff (max 5 attempts)
- ✅ Channel subscription/unsubscription
- ✅ Event binding/unbinding
- ✅ REST API publishing with HMAC
- ✅ iOS, Android, Web, Desktop support

## API Reference

### PushStream

#### Constructor
```dart
PushStream(String appKey, {String wsUrl, String apiUrl})
```

#### Methods
- `Future<String?> connect()` - Connect to WebSocket server
- `Channel subscribe(String channelName)` - Subscribe to channel
- `void unsubscribe(String channelName)` - Unsubscribe from channel
- `void disconnect()` - Disconnect from server
- `Future<Map<String, dynamic>> publish(...)` - Publish event (server-side)

#### Properties
- `String? socketId` - Current socket ID
- `bool connected` - Connection status

### Channel

#### Methods
- `Channel bind(String event, Function(dynamic) callback)` - Bind to event
- `Channel unbind(String event, [Function(dynamic)? callback])` - Unbind from event
- `void unsubscribe()` - Unsubscribe from channel

## Platform Support

| Platform | Supported |
|----------|-----------|
| Android | ✅ |
| iOS | ✅ |
| Web | ✅ |
| macOS | ✅ |
| Windows | ✅ |
| Linux | ✅ |

## License

MIT License
