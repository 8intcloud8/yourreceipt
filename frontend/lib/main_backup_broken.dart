import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html show Blob, Url, AnchorElement, document;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'tabbed_app_final.dart';

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
  Uint8List? _imageBytes;
  Map<String, dynamic>? _jsonResult;
  String? _error;
  bool _loading = false;
  Map<String, dynamic>? _existingCsvFiles;
  bool _isSubmitted = false;
  Map<String, TextEditingController> _controllers = {};
  List<Map<String, TextEditingController>> _itemControllers = [];
  int _itemsUpdateCounter = 0; // Counter to trigger rebuilds when items change
  
  // Results storage
  List<Map<String, dynamic>> _submittedReceipts = [];
  
  // Tab controller
  late TabController _tabController;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _jsonResult = null;
        _error = null;
      });
      if (kIsWeb) {
        await _uploadImageWeb(bytes);
      } else {
        await _uploadImageMobile(bytes);
      }
    }
  }

  // Mobile-only image upload
  Future<void> _uploadImageMobile(Uint8List bytes) async {
    setState(() { _loading = true; _error = null; });
    try {
      final uri = Uri.parse('http://localhost:8000/upload');
      final base64img = base64Encode(bytes);
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': base64img}),
      );
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (_validateJson(data)) {
            setState(() { 
              _jsonResult = data;
              _isSubmitted = false; // Reset submitted state for new data
              _initializeControllers(data); // Initialize controllers for the new data
            });
          } else {
            setState(() { _error = 'Malformed response from server.'; });
          }
        } catch (e) {
          setState(() { _error = 'Malformed response from server.'; });
        }
      } else {
        setState(() { _error = 'Server error: ${response.statusCode}\n${response.body}'; });
      }
    } catch (e) {
      setState(() { _error = 'Network error: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  // Web-only image upload
  Future<void> _uploadImageWeb(Uint8List bytes) async {
    setState(() { _loading = true; _error = null; });
    try {
      final uri = Uri.parse('http://localhost:8000/upload');
      final base64img = base64Encode(bytes);
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image_base64': base64img}),
      );
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (_validateJson(data)) {
            setState(() { 
              _jsonResult = data;
              _isSubmitted = false; // Reset submitted state for new data
              _initializeControllers(data); // Initialize controllers for the new data
            });
          } else {
            setState(() { _error = 'Malformed response from server.'; });
          }
        } catch (e) {
          setState(() { _error = 'Malformed response from server.'; });
        }
      } else {
        setState(() { _error = 'Server error: ${response.statusCode}\n${response.body}'; });
      }
    } catch (e) {
      setState(() { _error = 'Network error: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  bool _validateJson(dynamic data) {
    if (data is! Map) return false;
    
    // Check if the response is in the new format with success and data fields
    if (data.containsKey('success') && data.containsKey('data')) {
      // Use the data field for validation
      data = data['data'];
    }
    
    final requiredHeader = ['merchant', 'address', 'date', 'total', 'items'];
    for (final key in requiredHeader) {
      if (!data.containsKey(key)) return false;
    }
    if (data['items'] is! List) return false;
    for (final item in data['items']) {
      if (item is! Map) return false;
      final itemKeys = ['name', 'qty', 'unit_price', 'total_price'];
      for (final k in itemKeys) {
        if (!item.containsKey(k)) return false;
      }
    }
    return true;
  }

  Future<void> _openCsvFile(String filename) async {
    final url = 'http://localhost:8000/receipts/$filename';
    final uri = Uri.parse(url);
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri);
    } else {
      setState(() {
        _error = 'Could not open CSV file: $url';
      });
    }
  }

  Future<void> _checkExistingReceipts() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:8000/receipts'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _existingCsvFiles = {
              'header_csv': data['header_csv'],
              'line_csv': data['line_csv'],
            };
          });
        }
      }
    } catch (e) {
      print('Error checking existing receipts: $e');
    }
  }

  void _showFullImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Receipt Image'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: Image.memory(_imageBytes!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkExistingReceipts();
    
    // Initialize tab controller
    _tabController = TabController(length: 2, vsync: this);
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
    
    // Dispose tab controller
    _tabController.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Scanner'),
        elevation: 4,
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
                  text: 'Results',
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
                        child: _imageBytes != null
                            ? Stack(
                                children: [
                                  // Scrollable image container
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SingleChildScrollView(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: 0,
                                          maxHeight: MediaQuery.of(context).size.height,
                                        ),
                                        child: GestureDetector(
                                          onTap: () => _showFullImage(context),
                                          child: Image.memory(
                                            _imageBytes!,
                                            width: double.infinity,
                                            fit: BoxFit.fitWidth,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Hint overlay
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.touch_app, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text(
                                            'Tap to enlarge',
                                            style: TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
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
                                    const SizedBox(height: 8),
                                    Text(
                                      'Capture a receipt to get started',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    // Capture button in red
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _pickImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture Receipt', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    if (_loading)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 8),
                            Text(
                              'Processing receipt...',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade700,
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
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Spacer
              const SizedBox(width: 16),
              // Right column: Extracted data
              Expanded(
                flex: 1,
                child: _jsonResult != null
                    ? Card(
                        elevation: 4,
                        margin: EdgeInsets.zero,
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Submit button at the top
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
                                        onPressed: () {
                                          _submitData();
                                        },
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 16),
                                // Extract the actual data from the response
                                Builder(builder: (context) {
                                  final data = _jsonResult!.containsKey('data') 
                                      ? _jsonResult!['data'] 
                                      : _jsonResult!;
                                  
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Merchant name with icon
                                      Row(
                                        children: [
                                          const Icon(Icons.store, size: 28, color: Colors.blue),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: !_isSubmitted
                                                ? TextField(
                                                    controller: _controllers['merchant'],
                                                    style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.blue,
                                                    ),
                                                    decoration: const InputDecoration(
                                                      border: OutlineInputBorder(),
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    ),
                                                  )
                                                : Text(
                                                    '${data['merchant'] ?? 'Unknown'}',
                                                    style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                          ),
                                        ],
                                      ),
                                      const Divider(),
                                      // Address with icon
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.location_on, color: Colors.grey),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: !_isSubmitted
                                                ? TextField(
                                                    controller: _controllers['address'],
                                                    style: const TextStyle(fontSize: 16),
                                                    decoration: const InputDecoration(
                                                      border: OutlineInputBorder(),
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    ),
                                                  )
                                                : Text(
                                                    '${data['address'] ?? 'Unknown'}',
                                                    style: const TextStyle(fontSize: 16),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Date with icon
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.calendar_today, color: Colors.grey),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: !_isSubmitted
                                                ? TextField(
                                                    controller: _controllers['date'],
                                                    style: const TextStyle(fontSize: 16),
                                                    decoration: const InputDecoration(
                                                      border: OutlineInputBorder(),
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    ),
                                                  )
                                                : Text(
                                                    '${data['date'] ?? 'Unknown'}',
                                                    style: const TextStyle(fontSize: 16),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // Total in green box
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
                                            const Text(
                                              'Total:',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            !_isSubmitted
                                              ? SizedBox(
                                                  width: 120,
                                                  child: TextField(
                                                    controller: _controllers['total'],
                                                    style: TextStyle(
                                                      fontSize: 22,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.green.shade800,
                                                    ),
                                                    textAlign: TextAlign.right,
                                                    decoration: const InputDecoration(
                                                      border: OutlineInputBorder(),
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    ),
                                                  ),
                                                )
                                              : Text(
                                                  '${data['total'] ?? 'Unknown'}',
                                                  style: TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green.shade800,
                                                  ),
                                                ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      // Items section
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade200),
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: const [
                                                Icon(Icons.receipt_long, color: Colors.blue),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Items',
                                                  style: TextStyle(
                                                    fontSize: 18, 
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            if (data.containsKey('items') && data['items'] is List && (data['items'] as List).isNotEmpty)
                                              Column(
                                                children: [
                                                  // Table header
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.shade50,
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(8),
                                                        topRight: Radius.circular(8),
                                                      ),
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
                                                  for (int i = 0; i < data['items'].length; i++)
                                                    Container(
                                                      color: i % 2 == 0 ? Colors.white : Colors.grey.shade50,
                                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                                      child: !_isSubmitted
                                                        ? Row(
                                                            children: [
                                                              Expanded(
                                                                flex: 1,
                                                                child: Text(
                                                                  '${i + 1}',
                                                                  textAlign: TextAlign.center,
                                                                  style: TextStyle(
                                                                    color: Colors.grey.shade700,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                ),
                                                              ),
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
                                                              Expanded(
                                                                flex: 1, 
                                                                child: Text(
                                                                  '${i + 1}', 
                                                                  textAlign: TextAlign.center,
                                                                  style: TextStyle(
                                                                    color: Colors.grey.shade700,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                ),
                                                              ),
                                                              Expanded(flex: 3, child: Text(data['items'][i]['name'] ?? 'Unknown')),
                                                              Expanded(child: Text('${data['items'][i]['qty'] ?? ''}', textAlign: TextAlign.center)),
                                                              Expanded(flex: 2, child: Text(data['items'][i]['unit_price'] ?? '', textAlign: TextAlign.right)),
                                                              Expanded(
                                                                flex: 2, 
                                                                child: Text(
                                                                  data['items'][i]['total_price'] ?? '',
                                                                  textAlign: TextAlign.right,
                                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                                ),
                                                              ),
                                                              if (!_isSubmitted)
                                                                const Expanded(child: SizedBox()), // Empty space for alignment
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
                                                          const Expanded(flex: 7, child: SizedBox()), // Empty space to align with action column
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
                                                  // Sum of all items
                                                  Builder(
                                                    key: ValueKey(_itemsUpdateCounter), // Force rebuild when counter changes
                                                    builder: (context) {
                                                      // Calculate the sum of all item totals using controllers for real-time updates
                                                      double itemsTotal = 0.0;
                                                      if (!_isSubmitted && _itemControllers.isNotEmpty) {
                                                        // Use controller values for real-time calculation
                                                        itemsTotal = _getCurrentItemsTotal();
                                                      } else {
                                                        // Use data values for submitted state
                                                        for (var item in data['items']) {
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
                                                      
                                                      // Format the total with currency symbol
                                                      String formattedTotal = '\$${itemsTotal.toStringAsFixed(2)}';
                                                      
                                                      // Extract the receipt total for comparison
                                                      String receiptTotal = data['total'] ?? '';
                                                      String numericReceiptTotal = receiptTotal.replaceAll(RegExp(r'[^\d.]'), '');
                                                      double receiptTotalValue = 0.0;
                                                      try {
                                                        receiptTotalValue = double.parse(numericReceiptTotal);
                                                      } catch (e) {
                                                        // Use 0 if can't parse
                                                      }
                                                      
                                                      // Check if totals match (within a small margin for rounding errors)
                                                      bool totalsMatch = (receiptTotalValue - itemsTotal).abs() < 0.02;
                                                      
                                                      return Container(
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey.shade200,
                                                          border: Border(
                                                            top: BorderSide(color: Colors.grey.shade400, width: 1),
                                                          ),
                                                        ),
                                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                                        child: Column(
                                                          children: [
                                                            Row(
                                                              children: [
                                                                const Expanded(flex: 6, child: Text('Items Total:', style: TextStyle(fontWeight: FontWeight.bold))),
                                                                Expanded(
                                                                  flex: 2,
                                                                  child: Row(
                                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                                    children: [
                                                                      Text(
                                                                        formattedTotal,
                                                                        textAlign: TextAlign.right,
                                                                        style: TextStyle(
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 16,
                                                                          color: totalsMatch ? Colors.green.shade800 : Colors.orange.shade800,
                                                                        ),
                                                                      ),
                                                                      const SizedBox(width: 4),
                                                                      if (!totalsMatch)
                                                                        Tooltip(
                                                                          message: 'The sum of line items does not match the receipt total',
                                                                          child: Icon(
                                                                            Icons.warning_amber_rounded,
                                                                            color: Colors.orange.shade800,
                                                                            size: 16,
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              'Total Items: ${data['items'].length}',
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
                                                ],
                                              )
                                            else
                                              const Padding(
                                                padding: EdgeInsets.all(16.0),
                                                child: Text('No items found'),
                                              ),

                                          ],
                                        ),
                                      ),
                                      
                                      // Display CSV file links if available
                                      if (_jsonResult!.containsKey('header_csv') && _jsonResult!.containsKey('lines_csv'))
                                        Container(
                                          margin: const EdgeInsets.only(top: 24.0),
                                          padding: const EdgeInsets.all(16.0),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: const [
                                                  Icon(Icons.file_download, color: Colors.blue),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'CSV Files',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              InkWell(
                                                onTap: () => _openCsvFile(_jsonResult!['header_csv']),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.description, size: 16, color: Colors.blue),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          'Header CSV: ${_jsonResult!['header_csv']}',
                                                          style: const TextStyle(
                                                            color: Colors.blue,
                                                            decoration: TextDecoration.underline,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: () => _openCsvFile(_jsonResult!['lines_csv']),
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.receipt, size: 16, color: Colors.blue),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          'Lines CSV: ${_jsonResult!['lines_csv']}',
                                                          style: const TextStyle(
                                                            color: Colors.blue,
                                                            decoration: TextDecoration.underline,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Card(
                        elevation: 4,
                        margin: EdgeInsets.zero,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.blue.shade50,
                                Colors.blue.shade100,
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.receipt_outlined,
                                size: 64,
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No receipt data yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Capture a receipt image to extract data',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
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
            // Header with export button
            Row(
              children: [
                const Icon(Icons.list_alt, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Submitted Receipts',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
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
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No receipts submitted yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Submit receipts from the Scanner tab to see them here',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                            ),
                          ),
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
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                            ),
                            child: Row(
                              children: const [
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
                                    border: Border(
                                      bottom: BorderSide(color: Colors.grey.shade200),
                                    ),
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

  // Add these new methods for handling editable fields
  void _initializeControllers(Map<String, dynamic> jsonResult) {
    // Extract the actual data from the response
    final data = jsonResult.containsKey('data') 
        ? jsonResult['data'] 
        : jsonResult;
    
    // Initialize controllers for header fields
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
        
        // Add listeners to qty and unit_price to auto-calculate total_price
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
      
      // Remove currency symbols and parse
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
        // If parsing fails, set to 0
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
    if (_jsonResult != null) {
      Map<String, dynamic> data = _jsonResult!.containsKey('data') 
          ? _jsonResult!['data'] 
          : _jsonResult!;
      
      double itemsTotal = _getCurrentItemsTotal();
      
      // Don't update the receipt total field - keep it static
      // String formattedTotal = '\$${itemsTotal.toStringAsFixed(2)}';
      // _controllers['total']?.text = formattedTotal;
      // data['total'] = formattedTotal;
      
      // Trigger rebuild
      setState(() {
        _itemsUpdateCounter++;
      });
    }
  }

  void _addItem() {
    setState(() {
      int newIndex = _itemControllers.length;
      
      // Add new item to controllers
      var controllers = {
        'name': TextEditingController(text: ''),
        'qty': TextEditingController(text: '1'),
        'unit_price': TextEditingController(text: '0.00'),
        'total_price': TextEditingController(text: '0.00'),
      };
      
      // Add listeners to the new controllers
      controllers['qty']!.addListener(() => _updateItemTotal(newIndex));
      controllers['unit_price']!.addListener(() => _updateItemTotal(newIndex));
      controllers['total_price']!.addListener(() => _calculateItemsTotal());
      
      _itemControllers.add(controllers);
      
      // Add new item to data
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
      
      // Trigger immediate update
      _itemsUpdateCounter++;
    });
    
    // Recalculate total after setState
    Future.microtask(() => _calculateItemsTotal());
  }
  
  void _removeItem(int index) {
    if (index >= 0 && index < _itemControllers.length) {
      setState(() {
        // Dispose controllers for the item being removed
        for (var controller in _itemControllers[index].values) {
          controller.dispose();
        }
        
        // Remove from controllers
        _itemControllers.removeAt(index);
        
        // Remove from data
        if (_jsonResult != null) {
          Map<String, dynamic> data = _jsonResult!.containsKey('data') 
              ? _jsonResult!['data'] 
              : _jsonResult!;
          
          if (data['items'] is List && index < data['items'].length) {
            data['items'].removeAt(index);
          }
        }
        
        // Trigger immediate update
        _itemsUpdateCounter++;
      });
      
      // Recalculate total after setState
      Future.microtask(() => _calculateItemsTotal());
    }
  }

  void _submitData() {
    // Update the data with edited values
    if (_jsonResult != null) {
      Map<String, dynamic> data = _jsonResult!.containsKey('data') 
          ? _jsonResult!['data'] 
          : _jsonResult!;
      
      // Update header fields
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
      Map<String, dynamic> receiptResult = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(), // Unique ID
        'merchant': data['merchant'] ?? '',
        'address': data['address'] ?? '',
        'date': data['date'] ?? '',
        'total': data['total'] ?? '',
        'submittedAt': DateTime.now().toIso8601String(),
        'fullData': Map<String, dynamic>.from(data), // Store full data for editing
      };
      
      // Update the state to reflect changes and mark as submitted
      setState(() {
        if (_jsonResult!.containsKey('data')) {
          _jsonResult!['data'] = data;
        } else {
          _jsonResult = data;
        }
        _isSubmitted = true;
        _submittedReceipts.add(receiptResult);
      });
      
      // Show a confirmation message
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
    // Switch to scanner tab and load the receipt data for editing
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
    // TODO: Implement CSV export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV export feature coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
