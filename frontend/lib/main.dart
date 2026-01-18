import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'package:universal_html/html.dart' as html;
import 'auth_service.dart';
import 'login_screen.dart';
import 'websocket_service.dart';

void main() => runApp(const ReceiptApp());

class ReceiptApp extends StatelessWidget {
  const ReceiptApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const ReceiptHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ReceiptHomePage extends StatefulWidget {
  const ReceiptHomePage({super.key});
  @override
  State<ReceiptHomePage> createState() => _ReceiptHomePageState();
}

class _ReceiptHomePageState extends State<ReceiptHomePage> with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  bool _isAuthenticated = false;
  bool _isCheckingAuth = true;
  Map<String, dynamic>? _currentUser;
  
  Uint8List? _imageBytes;
  Map<String, dynamic>? _jsonResult;
  String? _error;
  bool _loading = false;
  bool _isSubmitted = false;
  Map<String, TextEditingController> _controllers = {};
  List<Map<String, TextEditingController>> _itemControllers = [];
  int _itemsUpdateCounter = 0;
  
  // Results storage
  List<Map<String, dynamic>> _submittedReceipts = [];
  List<Map<String, dynamic>> _allLineItems = [];
  
  // Tab controller
  late TabController _tabController;
  
  // WebSocket service
  WebSocketService? _wsService;
  String _progressMessage = '';
  int _progressPercent = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAuthStatus();
    _initializeWebSocket();
  }
  
  void _initializeWebSocket() {
    _wsService = WebSocketService();
    
    // Listen to WebSocket messages
    _wsService!.messages.listen((message) {
      print('WebSocket message received: $message');
      final type = message['type'];
      
      if (type == 'progress') {
        print('Progress update: ${message['message']} - ${message['progress']}%');
        setState(() {
          _progressMessage = message['message'] ?? '';
          _progressPercent = message['progress'] ?? 0;
        });
        print('After progress setState: _imageBytes is ${_imageBytes != null ? "NOT NULL" : "NULL"}');
      } else if (type == 'result') {
        print('Result received, setting state...');
        setState(() {
          _jsonResult = message['data'];
          _isSubmitted = false;
          _loading = false;
          _progressMessage = '';
          _progressPercent = 0;
          _initializeControllers(message['data']);
        });
        print('After result setState: _imageBytes is ${_imageBytes != null ? "NOT NULL (${_imageBytes!.length} bytes)" : "NULL"}');
      } else if (type == 'error') {
        print('Error received: ${message['message']}');
        setState(() {
          _error = message['message'] ?? 'Unknown error';
          _loading = false;
          _progressMessage = '';
          _progressPercent = 0;
        });
        print('After error setState: _imageBytes is ${_imageBytes != null ? "NOT NULL" : "NULL"}');
      }
    });
    
    // Listen to connection status
    _wsService!.status.listen((status) {
      print('WebSocket status: $status');
    });
  }
  
  Future<void> _checkAuthStatus() async {
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        final user = await _authService.getCurrentUser();
        setState(() {
          _isAuthenticated = true;
          _currentUser = user;
          _isCheckingAuth = false;
        });
      } else {
        setState(() {
          _isAuthenticated = false;
          _isCheckingAuth = false;
        });
      }
    } catch (e) {
      // If auth check fails, assume not authenticated
      print('Auth check error: $e');
      setState(() {
        _isAuthenticated = false;
        _isCheckingAuth = false;
      });
    }
  }
  
  void _onLoginSuccess() {
    _checkAuthStatus();
  }
  
  Future<void> _signOut() async {
    await _authService.signOut();
    setState(() {
      _isAuthenticated = false;
      _currentUser = null;
    });
  }
  
  @override
  void dispose() {
    // Dispose controllers
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    for (var item in _itemControllers) {
      for (var controller in item.values) {
        controller.dispose();
      }
    }
    _tabController.dispose();
    _wsService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking auth
    if (_isCheckingAuth) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade50, Colors.white],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    
    // Show login screen if not authenticated
    if (!_isAuthenticated) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }
    
    // Show main app if authenticated
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // User profile and sign out
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _currentUser?['name']?.substring(0, 1).toUpperCase() ?? 'U',
                style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.bold),
              ),
            ),
            onSelected: (value) {
              if (value == 'signout') {
                _signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentUser?['name'] ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _currentUser?['email'] ?? '',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'signout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.camera_alt),
                  text: 'Scanner',
                ),
                Tab(
                  icon: Icon(Icons.list_alt),
                  text: 'Header Items',
                ),
                Tab(
                  icon: Icon(Icons.receipt_long),
                  text: 'Line Items',
                ),
              ],
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
            ),
          ),
          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Scanner Tab
                _buildScannerTab(),
                // Results Tab
                _buildResultsTab(),
                // Line Items Tab
                _buildLineItemsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade50, Colors.white],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column: Image and capture button
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image container
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Builder(
                        builder: (context) {
                          print('Building image container: _imageBytes is ${_imageBytes != null ? "NOT NULL (${_imageBytes!.length} bytes)" : "NULL"}');
                          return _imageBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: InteractiveViewer(
                                    panEnabled: true,
                                    scaleEnabled: true,
                                    minScale: 0.5,
                                    maxScale: 5.0,
                                    constrained: false,
                                    child: Image.memory(
                                      _imageBytes!,
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.receipt_long,
                                        size: 64,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No receipt image',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                        },
                      ),
                    ),
                  ),
                  // Capture button
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _pickImage,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture Receipt', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  if (_loading)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 8),
                          Text(_progressMessage.isEmpty ? 'Processing receipt...' : _progressMessage),
                          if (_progressPercent > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: LinearProgressIndicator(
                                value: _progressPercent / 100,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 16.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Right column: Extracted data
            Expanded(
              flex: 1,
              child: _jsonResult != null
                  ? _buildReceiptData()
                  : Card(
                      elevation: 4,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_outlined, size: 64, color: Colors.blue),
                            SizedBox(height: 16),
                            Text('No receipt data yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            Text('Capture a receipt image to extract data', textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptData() {
    final data = _jsonResult!.containsKey('data') ? _jsonResult!['data'] : _jsonResult!;
    
    return Card(
      elevation: 4,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Submit button
              if (!_isSubmitted)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Submit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _submitData,
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              
              // Merchant
              _buildDataField('Merchant', data['merchant'] ?? '', Icons.store, 'merchant'),
              const SizedBox(height: 12),
              
              // Address
              _buildDataField('Address', data['address'] ?? '', Icons.location_on, 'address'),
              const SizedBox(height: 12),
              
              // Date
              _buildDataField('Date', data['date'] ?? '', Icons.calendar_today, 'date'),
              const SizedBox(height: 16),
              
              // Total
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    !_isSubmitted
                        ? SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _controllers['total'],
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          )
                        : Text(
                            data['total'] ?? 'Unknown',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Items section
              if (data.containsKey('items') && data['items'] is List)
                _buildItemsSection(data['items']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataField(String label, String value, IconData icon, String key) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              !_isSubmitted
                  ? TextField(
                      controller: _controllers[key],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    )
                  : Text(value.isEmpty ? 'Unknown' : value),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemsSection(List items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.blue),
              SizedBox(width: 8),
              Text('Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isNotEmpty) ...[
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  const Expanded(flex: 1, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  const Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
                  const Expanded(child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  const Expanded(flex: 2, child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  const Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  if (!_isSubmitted)
                    const Expanded(child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                ],
              ),
            ),
            // Table rows
            for (int i = 0; i < items.length; i++)
              Container(
                color: i % 2 == 0 ? Colors.white : Colors.grey.shade50,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: !_isSubmitted
                    ? Row(
                        children: [
                          Expanded(flex: 1, child: Text('${i + 1}', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500))),
                          Expanded(
                            flex: 3,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: TextField(
                                controller: _itemControllers[i]['name'],
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: TextField(
                                controller: _itemControllers[i]['qty'],
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: TextField(
                                controller: _itemControllers[i]['unit_price'],
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: TextField(
                                controller: _itemControllers[i]['total_price'],
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: IconButton(
                                onPressed: () => _removeItem(i),
                                icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(flex: 1, child: Text('${i + 1}', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500))),
                          Expanded(flex: 3, child: Text(items[i]['name'] ?? 'Unknown')),
                          Expanded(child: Text('${items[i]['qty'] ?? ''}', textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text(items[i]['unit_price'] ?? '', textAlign: TextAlign.right)),
                          Expanded(flex: 2, child: Text(items[i]['total_price'] ?? '', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                          if (!_isSubmitted)
                            const Expanded(child: SizedBox()),
                        ],
                      ),
              ),
            // Add Item button row
            if (!_isSubmitted)
              Container(
                color: Colors.green.shade50,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    const Expanded(flex: 7, child: SizedBox()),
                    Expanded(
                      child: Center(
                        child: IconButton(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add, color: Colors.green, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          tooltip: 'Add Item',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Items total
            Builder(
              key: ValueKey(_itemsUpdateCounter),
              builder: (context) {
                double itemsTotal = 0.0;
                if (!_isSubmitted && _itemControllers.isNotEmpty) {
                  itemsTotal = _getCurrentItemsTotal();
                } else {
                  for (var item in items) {
                    String totalPrice = item['total_price'] ?? '';
                    if (totalPrice.isNotEmpty) {
                      String numericValue = totalPrice.replaceAll(RegExp(r'[^\d.]'), '');
                      try {
                        itemsTotal += double.parse(numericValue);
                      } catch (e) {
                        // Skip if can't parse
                      }
                    }
                  }
                }
                
                String formattedTotal = '\$${itemsTotal.toStringAsFixed(2)}';
                
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    border: Border(top: BorderSide(color: Colors.grey.shade400, width: 1)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(flex: 6, child: Text('Items Total:', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(
                            flex: 2,
                            child: Text(
                              formattedTotal,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Items: ${items.length}',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No items found'),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade50, Colors.white],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.list_alt, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Header Items',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const Spacer(),
                if (_submittedReceipts.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _exportToCSV,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Results table
            Expanded(
              child: _submittedReceipts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('No receipts submitted yet', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                          const SizedBox(height: 8),
                          Text('Submit receipts from the Scanner tab to see them here', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : Card(
                      elevation: 4,
                      child: Column(
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                            ),
                            child: const Row(
                              children: [
                                Expanded(flex: 2, child: Text('Merchant', style: TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text('Address', style: TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(child: Text('Submitted', style: TextStyle(fontWeight: FontWeight.bold))),
                                SizedBox(width: 100, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                          // Table rows
                          Expanded(
                            child: ListView.builder(
                              itemCount: _submittedReceipts.length,
                              itemBuilder: (context, index) {
                                final receipt = _submittedReceipts[index];
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 2, child: Text(receipt['merchant'] ?? '')),
                                      Expanded(flex: 2, child: Text(receipt['address'] ?? '')),
                                      Expanded(child: Text(receipt['date'] ?? '')),
                                      Expanded(child: Text(receipt['total'] ?? '')),
                                      Expanded(child: Text(_formatDateTime(receipt['submittedAt']))),
                                      SizedBox(
                                        width: 100,
                                        child: Row(
                                          children: [
                                            IconButton(
                                              onPressed: () => _viewReceipt(receipt),
                                              icon: const Icon(Icons.visibility, color: Colors.blue, size: 18),
                                              tooltip: 'View/Edit',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                            ),
                                            IconButton(
                                              onPressed: () => _deleteReceipt(index),
                                              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                              tooltip: 'Delete',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      print('Image picked: ${bytes.length} bytes');
      setState(() {
        _imageBytes = bytes;
        _jsonResult = null;
        _error = null;
      });
      print('Image bytes set in state: ${_imageBytes?.length}');
      await _uploadImage(bytes);
    }
  }

  Future<void> _uploadImage(Uint8List bytes) async {
    setState(() { 
      _loading = true; 
      _error = null;
      _progressMessage = 'Connecting...';
      _progressPercent = 0;
    });
    
    try {
      final base64img = base64Encode(bytes);
      
      // Connect to WebSocket if not already connected
      if (!_wsService!.isConnected) {
        await _wsService!.connect();
      }
      
      // Send the image for processing
      await _wsService!.processReceipt(base64img);
      
    } catch (e) {
      setState(() { 
        _error = 'Connection error: $e';
        _loading = false;
        _progressMessage = '';
        _progressPercent = 0;
      });
    }
  }

  void _initializeControllers(Map<String, dynamic> jsonResult) {
    final data = jsonResult.containsKey('data') ? jsonResult['data'] : jsonResult;
    
    _controllers['merchant'] = TextEditingController(text: data['merchant'] ?? '');
    _controllers['address'] = TextEditingController(text: data['address'] ?? '');
    _controllers['date'] = TextEditingController(text: data['date'] ?? '');
    _controllers['total'] = TextEditingController(text: data['total'] ?? '');
    
    // Initialize controllers for items
    _itemControllers = [];
    if (data.containsKey('items') && data['items'] is List) {
      for (int i = 0; i < data['items'].length; i++) {
        var item = data['items'][i];
        var controllers = {
          'name': TextEditingController(text: item['name'] ?? ''),
          'qty': TextEditingController(text: item['qty']?.toString() ?? ''),
          'unit_price': TextEditingController(text: item['unit_price'] ?? ''),
          'total_price': TextEditingController(text: item['total_price'] ?? ''),
        };
        
        // Add listeners for auto-calculation
        controllers['qty']!.addListener(() => _updateItemTotal(i));
        controllers['unit_price']!.addListener(() => _updateItemTotal(i));
        controllers['total_price']!.addListener(() => _calculateItemsTotal());
        
        _itemControllers.add(controllers);
      }
    }
  }

  void _updateItemTotal(int index) {
    if (index >= 0 && index < _itemControllers.length) {
      String qtyText = _itemControllers[index]['qty']?.text ?? '1';
      String priceText = _itemControllers[index]['unit_price']?.text ?? '0.00';
      
      String numericQty = qtyText.replaceAll(RegExp(r'[^\d.]'), '');
      String numericPrice = priceText.replaceAll(RegExp(r'[^\d.]'), '');
      
      try {
        double qty = double.parse(numericQty.isEmpty ? '1' : numericQty);
        double price = double.parse(numericPrice.isEmpty ? '0' : numericPrice);
        double total = qty * price;
        
        String formattedTotal = '\$${total.toStringAsFixed(2)}';
        _itemControllers[index]['total_price']?.text = formattedTotal;
        
        // Update the data as well
        if (_jsonResult != null) {
          Map<String, dynamic> data = _jsonResult!.containsKey('data') 
              ? _jsonResult!['data'] 
              : _jsonResult!;
          
          if (data['items'] is List && index < data['items'].length) {
            data['items'][index]['total_price'] = formattedTotal;
          }
        }
      } catch (e) {
        _itemControllers[index]['total_price']?.text = '\$0.00';
      }
    }
  }

  double _getCurrentItemsTotal() {
    double itemsTotal = 0.0;
    for (int i = 0; i < _itemControllers.length; i++) {
      String totalPrice = _itemControllers[i]['total_price']?.text ?? '0.00';
      String numericValue = totalPrice.replaceAll(RegExp(r'[^\d.]'), '');
      try {
        itemsTotal += double.parse(numericValue);
      } catch (e) {
        // Skip if can't parse
      }
    }
    return itemsTotal;
  }

  void _calculateItemsTotal() {
    setState(() {
      _itemsUpdateCounter++;
    });
  }

  void _addItem() {
    setState(() {
      int newIndex = _itemControllers.length;
      
      var controllers = {
        'name': TextEditingController(text: ''),
        'qty': TextEditingController(text: '1'),
        'unit_price': TextEditingController(text: '0.00'),
        'total_price': TextEditingController(text: '0.00'),
      };
      
      controllers['qty']!.addListener(() => _updateItemTotal(newIndex));
      controllers['unit_price']!.addListener(() => _updateItemTotal(newIndex));
      controllers['total_price']!.addListener(() => _calculateItemsTotal());
      
      _itemControllers.add(controllers);
      
      if (_jsonResult != null) {
        Map<String, dynamic> data = _jsonResult!.containsKey('data') 
            ? _jsonResult!['data'] 
            : _jsonResult!;
        
        if (data['items'] is List) {
          data['items'].add({
            'name': '',
            'qty': '1',
            'unit_price': '0.00',
            'total_price': '0.00',
          });
        }
      }
      
      _itemsUpdateCounter++;
    });
  }
  
  void _removeItem(int index) {
    if (index >= 0 && index < _itemControllers.length) {
      setState(() {
        for (var controller in _itemControllers[index].values) {
          controller.dispose();
        }
        
        _itemControllers.removeAt(index);
        
        if (_jsonResult != null) {
          Map<String, dynamic> data = _jsonResult!.containsKey('data') 
              ? _jsonResult!['data'] 
              : _jsonResult!;
          
          if (data['items'] is List && index < data['items'].length) {
            data['items'].removeAt(index);
          }
        }
        
        _itemsUpdateCounter++;
      });
    }
  }

  void _submitData() {
    if (_jsonResult != null) {
      final data = _jsonResult!.containsKey('data') ? _jsonResult!['data'] : _jsonResult!;
      
      // Update data with edited values
      data['merchant'] = _controllers['merchant']?.text ?? data['merchant'];
      data['address'] = _controllers['address']?.text ?? data['address'];
      data['date'] = _controllers['date']?.text ?? data['date'];
      data['total'] = _controllers['total']?.text ?? data['total'];
      
      // Update items
      for (int i = 0; i < data['items'].length && i < _itemControllers.length; i++) {
        data['items'][i]['name'] = _itemControllers[i]['name']?.text ?? data['items'][i]['name'];
        data['items'][i]['qty'] = _itemControllers[i]['qty']?.text ?? data['items'][i]['qty'];
        data['items'][i]['unit_price'] = _itemControllers[i]['unit_price']?.text ?? data['items'][i]['unit_price'];
        data['items'][i]['total_price'] = _itemControllers[i]['total_price']?.text ?? data['items'][i]['total_price'];
      }
      
      // Save to results list
      final receiptResult = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'merchant': data['merchant'] ?? '',
        'address': data['address'] ?? '',
        'date': data['date'] ?? '',
        'total': data['total'] ?? '',
        'submittedAt': DateTime.now().toIso8601String(),
        'fullData': Map<String, dynamic>.from(data),
      };
      
      // Add line items to the global line items list
      if (data['items'] != null && data['items'] is List) {
        for (var item in data['items']) {
          final lineItem = {
            'receiptId': receiptResult['id'],
            'merchant': data['merchant'] ?? '',
            'date': data['date'] ?? '',
            'itemName': item['name'] ?? '',
            'quantity': item['qty'] ?? '',
            'unitPrice': item['unit_price'] ?? '',
            'totalPrice': item['total_price'] ?? '',
            'submittedAt': DateTime.now().toIso8601String(),
          };
          _allLineItems.add(lineItem);
        }
      }
      
      setState(() {
        _isSubmitted = true;
        _submittedReceipts.add(receiptResult);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt data submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  void _viewReceipt(Map<String, dynamic> receipt) {
    setState(() {
      _jsonResult = {'data': receipt['fullData']};
      _isSubmitted = false;
      _initializeControllers(_jsonResult!);
      _tabController.animateTo(0); // Switch to scanner tab
    });
  }

  void _deleteReceipt(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipt'),
        content: const Text('Are you sure you want to delete this receipt?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _submittedReceipts.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _exportToCSV() {
    // Generate CSV content for header items
    final csvContent = _generateHeaderCSV();
    
    if (kIsWeb) {
      // For web, trigger file download
      _downloadCSVFile(csvContent, 'header_items_${DateTime.now().millisecondsSinceEpoch}.csv');
    } else {
      // For mobile, show dialog (fallback)
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Header Items CSV Export'),
          content: SingleChildScrollView(
            child: Text(csvContent, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Header Items CSV exported successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _generateHeaderCSV() {
    final buffer = StringBuffer();
    buffer.writeln('Merchant,Address,Date,Total,Submitted At');
    
    for (final receipt in _submittedReceipts) {
      buffer.writeln(
        '"${receipt['merchant'] ?? ''}",'
        '"${receipt['address'] ?? ''}",'
        '"${receipt['date'] ?? ''}",'
        '"${receipt['total'] ?? ''}",'
        '"${_formatDateTime(receipt['submittedAt'] ?? '')}"'
      );
    }
    
    return buffer.toString();
  }

  Widget _buildLineItemsTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade50, Colors.white],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'All Line Items',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                const Spacer(),
                if (_allLineItems.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _exportLineItemsToCSV,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Line items table
            Expanded(
              child: _allLineItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('No line items yet', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                          const SizedBox(height: 8),
                          Text('Submit receipts from the Scanner tab to see line items here', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : Card(
                      elevation: 4,
                      child: Column(
                        children: [
                          // Table header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                            ),
                            child: const Row(
                              children: [
                                Expanded(flex: 2, child: Text('Merchant', style: TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(flex: 1, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(flex: 3, child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(flex: 1, child: Text('Unit Price', style: TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(flex: 1, child: Text('Total Price', style: TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(flex: 1, child: Text('Submitted', style: TextStyle(fontWeight: FontWeight.bold))),
                                SizedBox(width: 80, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                          // Table rows
                          Expanded(
                            child: ListView.builder(
                              itemCount: _allLineItems.length,
                              itemBuilder: (context, index) {
                                final lineItem = _allLineItems[index];
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                    color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 2, child: Text(lineItem['merchant'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                                      Expanded(flex: 1, child: Text(lineItem['date'] ?? '')),
                                      Expanded(flex: 3, child: Text(lineItem['itemName'] ?? '')),
                                      Expanded(flex: 1, child: Text(lineItem['quantity'] ?? '', textAlign: TextAlign.center)),
                                      Expanded(flex: 1, child: Text(lineItem['unitPrice'] ?? '', textAlign: TextAlign.right)),
                                      Expanded(flex: 1, child: Text(lineItem['totalPrice'] ?? '', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(flex: 1, child: Text(_formatDateTime(lineItem['submittedAt'] ?? ''), style: const TextStyle(fontSize: 12))),
                                      SizedBox(
                                        width: 80,
                                        child: IconButton(
                                          onPressed: () => _deleteLineItem(index),
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                          tooltip: 'Delete',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          // Summary footer
                          if (_allLineItems.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                border: Border(top: BorderSide(color: Colors.grey.shade300)),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(flex: 7, child: Text('Total Items:', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${_allLineItems.length} items',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteLineItem(int index) {
    setState(() {
      _allLineItems.removeAt(index);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Line item deleted'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _exportLineItemsToCSV() {
    // Generate CSV content for line items
    final csvContent = _generateLineItemsCSV();
    
    if (kIsWeb) {
      // For web, trigger file download
      _downloadCSVFile(csvContent, 'line_items_${DateTime.now().millisecondsSinceEpoch}.csv');
    } else {
      // For mobile, show dialog (fallback)
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Line Items CSV Export'),
          content: SingleChildScrollView(
            child: Text(csvContent, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Line Items CSV exported successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _generateLineItemsCSV() {
    final buffer = StringBuffer();
    buffer.writeln('Merchant,Date,Item Name,Quantity,Unit Price,Total Price,Submitted At');
    
    for (final item in _allLineItems) {
      buffer.writeln(
        '"${item['merchant'] ?? ''}",'
        '"${item['date'] ?? ''}",'
        '"${item['itemName'] ?? ''}",'
        '"${item['quantity'] ?? ''}",'
        '"${item['unitPrice'] ?? ''}",'
        '"${item['totalPrice'] ?? ''}",'
        '"${_formatDateTime(item['submittedAt'] ?? '')}"'
      );
    }
    
    return buffer.toString();
  }

  void _downloadCSVFile(String csvContent, String filename) {
    if (kIsWeb) {
      // Create a blob with the CSV content
      final bytes = utf8.encode(csvContent);
      final blob = html.Blob([bytes], 'text/csv');
      
      // Create a download URL
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // Create a temporary anchor element and trigger download
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      
      html.document.body?.children.add(anchor);
      anchor.click();
      
      // Clean up
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    }
  }


}