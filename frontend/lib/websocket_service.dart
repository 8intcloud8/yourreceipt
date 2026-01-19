import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static const String wsUrl = 'wss://0exonxkki2.execute-api.ap-southeast-2.amazonaws.com/production';
  
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<String> get status => _statusController.stream;
  
  bool get isConnected => _channel != null;
  
  Future<void> connect() async {
    try {
      _statusController.add('Connecting...');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Wait for connection to be established
      await _channel!.ready;
      
      _statusController.add('Connected');
      
      // Listen to messages
      _channel!.stream.listen(
        (message) {
          try {
            final data = json.decode(message);
            _messageController.add(data);
          } catch (e) {
            print('Error parsing message: $e');
          }
        },
        onError: (error) {
          _statusController.add('Error: $error');
          disconnect();
        },
        onDone: () {
          _statusController.add('Disconnected');
          disconnect();
        },
      );
    } catch (e) {
      _statusController.add('Connection failed: $e');
      throw Exception('Failed to connect: $e');
    }
  }
  
  void sendMessage(Map<String, dynamic> message) {
    if (_channel == null) {
      throw Exception('WebSocket not connected');
    }
    _channel!.sink.add(json.encode(message));
  }
  
  Future<void> processReceipt(String base64Image) async {
    if (_channel == null) {
      await connect();
    }
    
    // Wait a bit to ensure connection is stable
    await Future.delayed(Duration(milliseconds: 500));
    
    print('Sending process message with image length: ${base64Image.length}');
    sendMessage({
      'action': 'process',
      'image_base64': base64Image,
    });
  }
  
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
  
  void dispose() {
    disconnect();
    _messageController.close();
    _statusController.close();
  }
}
