import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as url_launcher;

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
  bool _isSubmitted = false;
  Map<String, TextEditingController> _controllers = {};
  List<Map<String, TextEditingController>> _itemControllers = [];
  int _itemsUpdateCounter = 0;
  
  // Results storage
  List<Map<String, dynamic>> _submittedReceipts = [];
  
  // Tab controller
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
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
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                _imageBytes!,
                                width: double.infinity,
                                fit: BoxFit.cover,
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
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Processing receipt...'),
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
              child: const Row(
                children: [
                  Expanded(flex: 1, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  Expanded(flex: 3, child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                ],
              ),
            ),
            // Table rows
            for (int i = 0; i < items.length; i++)
              Container(
                color: i % 2 == 0 ? Colors.white : Colors.grey.shade50,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Expanded(flex: 1, child: Text('${i + 1}', textAlign: TextAlign.center)),
                    Expanded(flex: 3, child: Text(items[i]['name'] ?? 'Unknown')),
                    Expanded(child: Text('${items[i]['qty'] ?? ''}', textAlign: TextAlign.center)),
                    Expanded(flex: 2, child: Text(items[i]['unit_price'] ?? '', textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text(items[i]['total_price'] ?? '', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
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
                  'Submitted Receipts',
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
      setState(() {
        _imageBytes = bytes;
        _jsonResult = null;
        _error = null;
      });
      await _uploadImage(bytes);
    }
  }

  Future<void> _uploadImage(Uint8List bytes) async {
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
        final data = json.decode(response.body);
        setState(() { 
          _jsonResult = data;
          _isSubmitted = false;
          _initializeControllers(data);
        });
      } else {
        setState(() { _error = 'Server error: ${response.statusCode}'; });
      }
    } catch (e) {
      setState(() { _error = 'Network error: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _initializeControllers(Map<String, dynamic> jsonResult) {
    final data = jsonResult.containsKey('data') ? jsonResult['data'] : jsonResult;
    
    _controllers['merchant'] = TextEditingController(text: data['merchant'] ?? '');
    _controllers['address'] = TextEditingController(text: data['address'] ?? '');
    _controllers['date'] = TextEditingController(text: data['date'] ?? '');
    _controllers['total'] = TextEditingController(text: data['total'] ?? '');
  }

  void _submitData() {
    if (_jsonResult != null) {
      final data = _jsonResult!.containsKey('data') ? _jsonResult!['data'] : _jsonResult!;
      
      // Update data with edited values
      data['merchant'] = _controllers['merchant']?.text ?? data['merchant'];
      data['address'] = _controllers['address']?.text ?? data['address'];
      data['date'] = _controllers['date']?.text ?? data['date'];
      data['total'] = _controllers['total']?.text ?? data['total'];
      
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV export feature coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}