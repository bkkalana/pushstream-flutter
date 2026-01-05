import 'package:flutter/material.dart';
import 'package:pushstream/pushstream.dart';

void main() {
  runApp(const PushStreamExample());
}

class PushStreamExample extends StatefulWidget {
  const PushStreamExample({super.key});

  @override
  State<PushStreamExample> createState() => _PushStreamExampleState();
}

class _PushStreamExampleState extends State<PushStreamExample> {
  late PushStream client;
  String connectionStatus = 'Disconnected';
  String? socketId;
  final List<Map<String, dynamic>> messages = [];
  final TextEditingController channelController = TextEditingController();
  Channel? currentChannel;

  @override
  void initState() {
    super.initState();
    client = PushStream(
      'your-app-key',
      wsUrl: 'wss://ws.pushstream.ceylonitsolutions.online',
      apiUrl: 'https://api.pushstream.ceylonitsolutions.online',
    );
  }

  Future<void> _connect() async {
    try {
      setState(() => connectionStatus = 'Connecting...');
      final id = await client.connect();
      setState(() {
        connectionStatus = 'Connected';
        socketId = id;
      });
    } catch (e) {
      setState(() => connectionStatus = 'Error: $e');
    }
  }

  void _subscribe() {
    if (channelController.text.isEmpty) return;
    
    currentChannel = client.subscribe(channelController.text);
    currentChannel!.bind('test-event', (data) {
      setState(() {
        messages.insert(0, {
          'channel': channelController.text,
          'event': 'test-event',
          'data': data,
          'time': DateTime.now(),
        });
      });
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Subscribed to ${channelController.text}')),
    );
  }

  void _disconnect() {
    client.disconnect();
    setState(() {
      connectionStatus = 'Disconnected';
      socketId = null;
    });
  }

  @override
  void dispose() {
    client.disconnect();
    channelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PushStream Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(title: const Text('PushStream Flutter SDK')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: $connectionStatus',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (socketId != null)
                        Text('Socket ID: $socketId',
                            style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: client.connected ? null : _connect,
                            child: const Text('Connect'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: client.connected ? _disconnect : null,
                            child: const Text('Disconnect'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: channelController,
                        decoration: const InputDecoration(
                          labelText: 'Channel Name',
                          hintText: 'e.g., orders',
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: client.connected ? _subscribe : null,
                        child: const Text('Subscribe'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Messages:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: messages.isEmpty
                    ? const Center(child: Text('No messages yet'))
                    : ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          return Card(
                            child: ListTile(
                              title: Text('${msg['channel']} - ${msg['event']}'),
                              subtitle: Text(msg['data'].toString()),
                              trailing: Text(
                                '${msg['time'].hour}:${msg['time'].minute}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
