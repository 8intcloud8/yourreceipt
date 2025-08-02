import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
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
  Map<String, dynamic>? _existingCsvFiles;
  bool _isSubmitted = false;
  Map<String, TextEditingController> _controllers = {};
  List<Map<String, TextEditingController>> _itemControllers = [];
  
  // Tab controller
  late TabController _tabController;
  
  // Data for analysis tab
  List<Map<String, dynamic>> _receiptHeaders = [];
  List<Map<String, dynamic>> _receiptItems = [];
  bool _loadingAnalysisData = false;
  String? _analysisError;
  
  @override
  void initState() {
    super.initState();
    _checkExistingReceipts();
    
    // Initialize tab controller
    _tabController = TabController(length: 3, vsync: this);
    
    // Add listener to load data when Analysis tab is selected
    _tabController.addListener(() {
      if ((_tabController.index == 1 || _tabController.index == 2) && 
          !_loadingAnalysisData && _receiptHeaders.isEmpty) {
        _loadReceiptDataForAnalysis();
      }
    });
    
    // Load data for analysis tab
    _loadReceiptDataForAnalysis();
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
    if (data is! Map<String, dynamic>) return false;
    
    // Check for required fields in the response
    if (!data.containsKey('merchant') && 
        !data.containsKey('data')) {
      return false;
    }
    
    // If data is nested under 'data' key, check that structure
    if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
      final nestedData = data['data'];
      return nestedData.containsKey('merchant');
    }
    
    return true;
  }

  Future<void> _openCsvFile(String filename) async {
    final url = 'http://localhost:8000/receipts/$filename';
    final uri = Uri.parse(url);
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  Future<void> _checkExistingReceipts() async {
    try {
      final uri = Uri.parse('http://localhost:8000/receipts');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _existingCsvFiles = data;
        });
      }
    } catch (e) {
      // Silently fail, this is just a convenience feature
      print('Failed to check for existing receipts: $e');
    }
  }

  void _showFullImage(BuildContext context) {
    if (_imageBytes == null) return;
    
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

  Widget _buildReceiptCaptureTab() {
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
                            color: Colors.black.withAlpha(26),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Image or placeholder
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _imageBytes != null
                                ? GestureDetector(
                                    onTap: () => _showFullImage(context),
                                    child: Image.memory(
                                      _imageBytes!,
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey.shade100,
                                    child: const Center(
                                      child: Text(
                                        'No image selected',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                          
                          // Zoom hint
                          if (_imageBytes != null)
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(153),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.zoom_in,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tap to zoom',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                          // Loading indicator
                          if (_loading)
                            Container(
                              color: Colors.black.withAlpha(77),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Capture button
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _pickImage,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_loading ? 'Processing...' : 'Capture Receipt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
            
            // Divider
            const SizedBox(width: 16),
            
            // Right column: JSON result
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _jsonResult != null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Submit button
                            if (!_isSubmitted)
                              ElevatedButton.icon(
                                onPressed: _submitData,
                                icon: const Icon(Icons.check),
                                label: const Text('Submit'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            if (!_isSubmitted)
                              const SizedBox(height: 16),
                            // Header fields
                            Text(
                              'Receipt Information',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
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
                                  // Merchant
                                  _buildHeaderField(
                                    'Merchant',
                                    data['merchant'],
                                    _controllers['merchant'],
                                  ),
                                  const SizedBox(height: 8),
                                  // Address
                                  _buildHeaderField(
                                    'Address',
                                    data['address'],
                                    _controllers['address'],
                                  ),
                                  const SizedBox(height: 8),
                                  // Date
                                  _buildHeaderField(
                                    'Date',
                                    data['date'],
                                    _controllers['date'],
                                  ),
                                  const SizedBox(height: 8),
                                  // Total
                                  _buildHeaderField(
                                    'Total',
                                    data['total'],
                                    _controllers['total'],
                                  ),
                                ],
                              );
                            }),
                            const SizedBox(height: 24),
                            // Line items
                            Text(
                              'Line Items',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Calculate the total of line items
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Line Items Total: ',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                ),
                                Text(
                                  '\$' + _itemControllers.fold<double>(0.0, (sum, item) {
                                    final text = item['total_price']?.text ?? '';
                                    final value = double.tryParse(text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
                                    return sum + value;
                                  }).toStringAsFixed(2),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Line items table
                            Expanded(
                              child: SingleChildScrollView(
                                child: _buildItemsTable(),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Error: $_error',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          )
                        : const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Capture a receipt to see the extracted data here.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build the analysis tab
  Widget _buildAnalysisTab() {
    if (_loadingAnalysisData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_analysisError != null) {
      return Center(
        child: Text(
          'Error loading data: $_analysisError',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    
    if (_receiptItems.isEmpty) {
      return const Center(
        child: Text(
          'No receipt data available',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Receipt Analysis',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.refresh),
                  label: Text('Refresh'),
                  onPressed: _loadReceiptDataForAnalysis,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            // Merchant spending pie chart
            _buildMerchantTotalsPieChart(),
          ],
        ),
      ),
    );
  }
  
  // Build the Summary tab
  Widget _buildSummaryTab() {
    if (_loadingAnalysisData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_analysisError != null) {
      return Center(
        child: Text(
          'Error loading data: $_analysisError',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    
    if (_receiptItems.isEmpty) {
      return const Center(
        child: Text(
          'No receipt data available',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }
    
    // Aggregate items by name
    final Map<String, Map<String, dynamic>> aggregatedItems = {};
    
    for (var item in _receiptItems) {
      final name = item['name']?.toString() ?? '';
      if (name.isEmpty || name.toLowerCase().contains('bag')) continue;
      
      // Initialize if not exists
      if (!aggregatedItems.containsKey(name)) {
        aggregatedItems[name] = {
          'name': name,
          'count': 0,
          'total': 0.0,
        };
      }
      
      // Increment count
      aggregatedItems[name]!['count'] = (aggregatedItems[name]!['count'] as int) + 1;
      
      // Add to total
      double totalPrice = 0;
      if (item['total_price'] is double) {
        totalPrice = item['total_price'];
      } else if (item['total_price'] is String) {
        final priceStr = (item['total_price'] as String)
            .replaceAll('\$', '')
            .replaceAll('AUD', '')
            .replaceAll('/kg', '');
        totalPrice = double.tryParse(priceStr) ?? 0;
      }
      
      aggregatedItems[name]!['total'] = (aggregatedItems[name]!['total'] as double) + totalPrice;
    }
    
    // Convert to list and sort by count (descending)
    final sortedItems = aggregatedItems.values.toList();
    sortedItems.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Item Purchase Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          // Header row
          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.blue.shade100,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Item Name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Count',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Total Spent',
                    style: TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // List of items
          Expanded(
            child: ListView.builder(
              itemCount: sortedItems.length,
              itemBuilder: (context, index) {
                final item = sortedItems[index];
                final name = item['name'] as String;
                final count = item['count'] as int;
                final total = item['total'] as double;
                
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                    color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(name),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          count.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '\$${total.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Summary footer
          Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    sortedItems.fold<int>(0, (sum, item) => sum + (item['count'] as int)).toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '\$${sortedItems.fold<double>(0, (sum, item) => sum + (item['total'] as double)).toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Load receipt data for analysis
  Future<void> _loadReceiptDataForAnalysis() async {
    setState(() {
      _loadingAnalysisData = true;
      _analysisError = null;
    });
    
    try {
      // Fetch header.csv
      final headerUri = Uri.parse('http://localhost:8000/receipts/header.csv');
      final headerResponse = await http.get(headerUri);
      
      // Fetch line.csv
      final lineUri = Uri.parse('http://localhost:8000/receipts/line.csv');
      final lineResponse = await http.get(lineUri);
      
      if (headerResponse.statusCode == 200 && lineResponse.statusCode == 200) {
        // Parse CSV data
        setState(() {
          _receiptHeaders = _parseHeaderCsv(headerResponse.body);
          debugPrint('Parsed receipt headers: \n'+_receiptHeaders.toString());
          _parseLineCsv(lineResponse.body);
          _loadingAnalysisData = false;
        });
      } else {
        setState(() {
          _loadingAnalysisData = false;
          _analysisError = 'Failed to load receipt data';
        });
      }
    } catch (e) {
      setState(() {
        _loadingAnalysisData = false;
        _analysisError = 'Error: $e';
      });
    }
  }
  
  // Parse header.csv into a list of maps
  List<Map<String, dynamic>> _parseHeaderCsv(String csvData) {
    final lines = csvData.split('\n');
    if (lines.isEmpty) return [];
    
    // Skip header row
    lines.removeAt(0);
    
    // Group by receipt ID
    final Map<String, Map<String, dynamic>> receiptsMap = {};
    
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      
      final parts = line.split(',');
      if (parts.length < 3) continue;
      
      final id = parts[0].trim();
      final field = parts[1].trim().replaceAll('"', '');
      final value = parts.sublist(2).join(',').trim().replaceAll('"', '');
      
      if (!receiptsMap.containsKey(id)) {
        receiptsMap[id] = {'id': id};
      }
      
      receiptsMap[id]![field] = value;
    }
    
    return receiptsMap.values.toList();
  }
  
  // Parse line.csv data
  void _parseLineCsv(String csvData) {
    _receiptItems.clear(); // Ensure no duplicate accumulation
    final lines = csvData.split('\n');
    if (lines.length <= 1) return; // Only header or empty
    
    // Skip header row
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      final values = line.split(',');
      if (values.length >= 6) {
        // Parse total_price correctly
        String totalPriceStr = values[5];
        double totalPrice = 0.0;
        
        // Handle different formats of price
        if (totalPriceStr.startsWith('\$')) {
          totalPriceStr = totalPriceStr.substring(1);
        }
        
        try {
          totalPrice = double.parse(totalPriceStr);
        } catch (e) {
          // Try to handle other formats
          totalPriceStr = totalPriceStr.replaceAll('\$', '').replaceAll('/kg', '');
          try {
            totalPrice = double.parse(totalPriceStr);
          } catch (e) {
            // If still can't parse, leave as 0
          }
        }
        
        _receiptItems.add({
          'id': values[0],
          'receipt_id': values[1],
          'name': values[2],
          'qty': values[3],
          'unit_price': values[4],
          'total_price': totalPrice,
        });
      }
    }
  }
  
  // Get the top products with total spent
  List<Map<String, dynamic>> _getTopProducts() {
    if (_receiptItems.isEmpty) return [];
    
    // Group items by name and calculate total spent
    final Map<String, double> productTotals = {};
    final Map<String, int> productCounts = {};
    
    for (var item in _receiptItems) {
      final name = item['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      
      // Skip items with generic names
      if (name.toLowerCase().contains('bag')) {
        continue;
      }
      
      double totalPrice = 0;
      if (item['total_price'] is double) {
        totalPrice = item['total_price'];
      } else if (item['total_price'] is String) {
        final priceStr = (item['total_price'] as String)
            .replaceAll('\$', '')
            .replaceAll('AUD', '');
        totalPrice = double.tryParse(priceStr) ?? 0;
      }
      
      productTotals[name] = (productTotals[name] ?? 0) + totalPrice;
      productCounts[name] = (productCounts[name] ?? 0) + 1;
    }
    
    // Convert to list and sort by count (most purchased)
    final products = productTotals.entries.map((entry) {
      return {
        'name': entry.key,
        'total': entry.value,
        'count': productCounts[entry.key] ?? 0,
      };
    }).toList();
    
    // Sort by count (most purchased)
    products.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    
    // Return top 10 or fewer if less than 10 products
    return products.take(10).toList();
  }
  
  // Robust total parser for merchant totals
  double _parseMerchantTotal(dynamic totalField) {
    if (totalField is double) return totalField;
    if (totalField is String) {
      // Remove all non-numeric, non-dot, and non-comma characters
      var cleaned = totalField.replaceAll(RegExp(r'[^0-9\.,]'), '');
      // Replace comma with dot if present (for locales)
      cleaned = cleaned.replaceAll(',', '.');
      // Handle multiple dots (e.g., '142.43.00') by keeping only the first
      int firstDot = cleaned.indexOf('.');
      if (firstDot != -1 && cleaned.indexOf('.', firstDot + 1) != -1) {
        cleaned = cleaned.substring(0, cleaned.indexOf('.', firstDot + 1));
      }
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  // Get total spent by merchant
  List<Map<String, dynamic>> _getMerchantTotals() {
    if (_receiptHeaders.isEmpty) return [];
    
    // Group by merchant and calculate total spent
    final Map<String, double> merchantTotals = {};
    
    for (var receipt in _receiptHeaders) {
      final merchant = receipt['merchant']?.toString() ?? '';
      if (merchant.isEmpty) continue;
      
      double total = _parseMerchantTotal(receipt['total']);
      merchantTotals[merchant] = (merchantTotals[merchant] ?? 0) + total;
    }
    
    // Convert to list and sort by total spent
    final merchants = merchantTotals.entries.map((entry) {
      return {
        'merchant': entry.key,
        'total': entry.value,
      };
    }).toList();
    
    // Sort by total spent (highest first)
    merchants.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    
    return merchants;
  }
  
  // Custom bar chart for top products
  Widget _buildTopProductsBarChart() {
    final products = _getTopProducts();
    
    if (products.isEmpty) {
      return const Center(
        child: Text(
          'No product data available',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }
    
    // Find max value for scaling
    final maxValue = products.map((i) => i['count'] as int).reduce(max);
    
    // Build a simple custom bar chart
    return Container(
      height: 350,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Top 10 Most Frequently Purchased Products',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Y-axis with labels
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${maxValue}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    Text('${(maxValue * 0.75).round()}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    Text('${(maxValue * 0.5).round()}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    Text('${(maxValue * 0.25).round()}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    Text('0', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    SizedBox(height: 70), // Space for the labels below bars
                  ],
                ),
                SizedBox(width: 5),
                // Vertical axis line
                Container(
                  width: 1,
                  color: Colors.grey[300],
                  margin: EdgeInsets.only(bottom: 70), // Space for the labels below bars
                ),
                SizedBox(width: 10),
                // Bar chart content
                Expanded(
                  child: Stack(
                    children: [
                      // Horizontal grid lines
                      Positioned.fill(
                        bottom: 70, // Space for the labels below bars
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(5, (index) => 
                            Container(
                              height: 1,
                              color: Colors.grey[200],
                            )
                          ),
                        ),
                      ),
                      // Bars
                      ListView(
                        scrollDirection: Axis.horizontal,
                        children: products.map((item) {
                          final barHeight = ((item['count'] as int) / maxValue) * 180;
                          final name = item['name'] as String;
                          final total = item['total'] as double;
                          final formattedTotal = '\$${total.toStringAsFixed(2)}';
                          
                          return Container(
                            width: 80,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Total amount
                                Text(
                                  formattedTotal,
                                  style: TextStyle(
                                    fontSize: 12, 
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 5),
                                // Spacer that pushes the bar to the bottom
                                Spacer(),
                                // Bar
                                Container(
                                  width: 40,
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade400,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                // Label
                                Container(
                                  height: 60,
                                  width: 80,
                                  alignment: Alignment.center,
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Custom pie chart for merchant totals
  Widget _buildMerchantTotalsPieChart() {
    // Group by merchant and calculate totals
    final merchantTotals = _getMerchantTotals();

    if (merchantTotals.isEmpty) {
      return const Center(
        child: Text(
          'No merchant data available',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }

    // Calculate total for percentages
    final totalSpent = merchantTotals.fold(0.0, (sum, item) => sum + (item['total'] as double));

    // Sort merchants by total spent (descending)
    final sortedMerchants = List<Map<String, dynamic>>.from(merchantTotals)
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

    // Colors for pie chart slices
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.cyan,
    ];

    return Container(
      height: 500,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Total Spent by Merchant',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Pie Chart
                  Container(
                    width: 300,
                    height: 300,
                    child: CustomPaint(
                      painter: PieChartPainter(
                        values: sortedMerchants.map((e) => e['total'] as double).toList(),
                        colors: colors.sublist(0, min(sortedMerchants.length, colors.length)),
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                  // Legend
                  Container(
                    constraints: BoxConstraints(maxWidth: 300),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < sortedMerchants.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  color: i < colors.length ? colors[i] : Colors.grey,
                                ),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '${sortedMerchants[i]['merchant']} - ${(sortedMerchants[i]['total'] / totalSpent * 100).toStringAsFixed(1)}% (\$${sortedMerchants[i]['total'].toStringAsFixed(2)})',
                                    style: TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
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
    );
  }

  // Helper method to truncate long names
  String _truncateName(String name, int maxLength) {
    if (name.length <= maxLength) return name;
    return '${name.substring(0, maxLength - 3)}...';
  }

  // Helper method to build a header field
  Widget _buildHeaderField(String label, String? value, TextEditingController? controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
          ),
        ),
      ],
    );
  }

  // Helper method to build the items table
  Widget _buildItemsTable() {
    if (_itemControllers.isEmpty) {
      return const Center(
        child: Text(
          'No line items found',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      );
    }
    
    return Table(
      border: TableBorder.all(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      columnWidths: const {
        0: FlexColumnWidth(3), // Name
        1: FlexColumnWidth(1), // Qty
        2: FlexColumnWidth(2), // Unit Price
        3: FlexColumnWidth(2), // Total Price
      },
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          children: [
            _buildTableHeaderCell('Item'),
            _buildTableHeaderCell('Qty'),
            _buildTableHeaderCell('Unit Price'),
            _buildTableHeaderCell('Total'),
          ],
        ),
        // Item rows
        for (int i = 0; i < _itemControllers.length; i++)
          TableRow(
            children: [
              _buildTableCell(_itemControllers[i]['name']!),
              _buildTableCell(_itemControllers[i]['qty']!),
              _buildTableCell(_itemControllers[i]['unit_price']!),
              _buildTableCell(_itemControllers[i]['total_price']!),
            ],
          ),
      ],
    );
  }

  // Helper method to build a table header cell
  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Helper method to build a table cell with a text field
  Widget _buildTableCell(TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
        ),
      ),
    );
  }

  // Submit data to server
  Future<void> _submitData() async {
    if (_jsonResult == null) return;
    
    setState(() { _loading = true; });
    
    try {
      // Extract the actual data from the response
      final data = _jsonResult!.containsKey('data')
          ? _jsonResult!['data']
          : _jsonResult!;
      
      // Create a new data object with the edited values
      final Map<String, dynamic> submitData = {
        'merchant': _controllers['merchant']!.text,
        'address': _controllers['address']!.text,
        'date': _controllers['date']!.text,
        'total': _controllers['total']!.text,
        'items': _itemControllers.map((item) => {
          'name': item['name']!.text,
          'qty': item['qty']!.text,
          'unit_price': item['unit_price']!.text,
          'total_price': item['total_price']!.text,
        }).toList(),
      };
      
      // Send the data to the server
      final uri = Uri.parse('http://localhost:8000/submit');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(submitData),
      );
      
      if (response.statusCode == 200) {
        setState(() { 
          _isSubmitted = true;
          _existingCsvFiles = json.decode(response.body);
        });
        
        // Reload analysis data
        await _loadReceiptDataForAnalysis();
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Receipt submitted successfully!'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'View CSV',
                textColor: Colors.white,
                onPressed: () {
                  _openCsvFile('header.csv');
                },
              ),
            ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() { _loading = false; });
    }
  }

  // Initialize controllers for receipt data
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
      for (var item in data['items']) {
        _itemControllers.add({
          'name': TextEditingController(text: item['name'] ?? ''),
          'qty': TextEditingController(text: item['qty']?.toString() ?? ''),
          'unit_price': TextEditingController(text: item['unit_price'] ?? ''),
          'total_price': TextEditingController(text: item['total_price'] ?? ''),
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Scanner'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Receipt Capture'),
            Tab(text: 'Analysis'),
            Tab(text: 'Summary'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReceiptCaptureTab(),
          _buildAnalysisTab(),
          _buildSummaryTab(),
        ],
      ),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  PieChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 16;

    double startAngle = 0;
    for (var i = 0; i < values.length; i++) {
      final sweepAngle = (values[i] / values.fold(0, (sum, value) => sum + value)) * 2 * pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCenter(center: center, width: radius * 2, height: radius * 2),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
