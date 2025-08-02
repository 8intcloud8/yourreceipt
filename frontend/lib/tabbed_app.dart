import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:fl_chart/fl_chart.dart';

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
  
  @override
  void initState() {
    super.initState();
    _checkExistingReceipts();
    
    // Initialize tab controller
    _tabController = TabController(length: 2, vsync: this);
    
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Scanner'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.receipt), text: 'Receipt Capture'),
            Tab(icon: Icon(Icons.analytics), text: 'Analysis'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Receipt Capture - Original content
          _buildReceiptCaptureTab(),
          
          // Tab 2: Analysis
          _buildAnalysisTab(),
        ],
      ),
    );
  }
  
  // Helper method to build the receipt capture tab with the original content
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade50, Colors.white],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loadingAnalysisData
          ? const Center(child: CircularProgressIndicator())
          : _analysisError != null
            ? Center(
                child: Text(
                  'Error: $_analysisError',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                  ),
                ),
              )
            : Column(
                children: [
                  // Top products bar chart
                  Text(
                    'Top 4 Most Purchased Products',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: _buildTopProductsBarChart(),
                  ),
                  const SizedBox(height: 32),
                  
                  // Merchant totals pie chart
                  Text(
                    'Total Spent by Merchant',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: _buildMerchantTotalsPieChart(),
                  ),
                ],
              ),
      ),
    );
  }
  
  // Helper method to build the top products bar chart
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
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: products.map((p) => p['total'] as double).reduce((a, b) => a > b ? a : b) * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.shade800,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${products[groupIndex]['name']}\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: '\$${products[groupIndex]['total'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: '\nCount: ${products[groupIndex]['count']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: SideTitles(
            showTitles: true,
            getTitles: (value) {
              if (value < 0 || value >= products.length) {
                return '';
              }
              final name = products[value.toInt()]['name'].toString();
              // Truncate long names
              final displayName = name.length > 10 
                  ? '${name.substring(0, 8)}...' 
                  : name;
              return displayName;
            },
            getTextStyles: (context, value) => const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            margin: 10,
          ),
          leftTitles: SideTitles(
            showTitles: true,
            getTitles: (value) => '\$${value.toInt()}',
            getTextStyles: (context, value) => const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            margin: 10,
          ),
          topTitles: SideTitles(showTitles: false),
          rightTitles: SideTitles(showTitles: false),
        ),
        borderData: FlBorderData(
          show: false,
        ),
        barGroups: List.generate(
          products.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                y: products[index]['total'] as double,
                colors: [Colors.blue.shade400],
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper method to build the merchant totals pie chart
  Widget _buildMerchantTotalsPieChart() {
    final merchants = _getMerchantTotals();
    
    if (merchants.isEmpty) {
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
    final totalSpent = merchants.fold(0.0, (sum, item) => sum + (item['total'] as double));
    
    // Generate colors for pie chart sections
    final List<Color> colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
      Colors.yellow.shade700,
      Colors.pink.shade400,
    ];
    
    return PieChart(
      PieChartData(
        sections: List.generate(
          merchants.length,
          (index) {
            final merchant = merchants[index];
            final double total = merchant['total'] as double;
            final double percentage = (total / totalSpent) * 100;
            
            return PieChartSectionData(
              color: colors[index % colors.length],
              value: total,
              title: '${percentage.toStringAsFixed(1)}%',
              radius: 100,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              titlePositionPercentageOffset: 0.55,
            );
          },
        ),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        pieTouchData: PieTouchData(
          enabled: true,
        ),
      ),
    );
  }
  
  // Data for analysis tab
  List<Map<String, dynamic>> _receiptHeaders = [];
  List<Map<String, dynamic>> _receiptItems = [];
  bool _loadingAnalysisData = false;
  String? _analysisError;
  
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
        _receiptHeaders = _parseHeaderCsv(headerResponse.body);
        _receiptItems = _parseLineCsv(lineResponse.body);
        
        setState(() {
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
  
  // Parse line.csv into a list of maps
  List<Map<String, dynamic>> _parseLineCsv(String csvData) {
    final lines = csvData.split('\n');
    if (lines.isEmpty) return [];
    
    // Get header row
    final headers = lines[0].split(',');
    if (headers.length < 3) return [];
    
    // Skip header row
    lines.removeAt(0);
    
    final items = <Map<String, dynamic>>[];
    
    for (var line in lines) {
      if (line.trim().isEmpty) continue;
      
      final parts = line.split(',');
      if (parts.length < headers.length) continue;
      
      final item = <String, dynamic>{};
      
      for (var i = 0; i < headers.length; i++) {
        var value = parts[i].trim().replaceAll('"', '');
        
        // Try to convert numeric values
        if (i > 1) {
          try {
            if (value.startsWith('\$')) {
              value = value.substring(1);
            }
            if (value.startsWith('AUD\$')) {
              value = value.substring(4);
            }
            final numValue = double.tryParse(value);
            if (numValue != null) {
              item[headers[i]] = numValue;
              continue;
            }
          } catch (_) {}
        }
        
        item[headers[i]] = value;
      }
      
      items.add(item);
    }
    
    return items;
  }
  
  // Get the top 4 most purchased products with total spent
  List<Map<String, dynamic>> _getTopProducts() {
    if (_receiptItems.isEmpty) return [];
    
    // Group items by name and calculate total spent
    final Map<String, double> productTotals = {};
    final Map<String, int> productCounts = {};
    
    for (var item in _receiptItems) {
      final name = item['name']?.toString() ?? '';
      if (name.isEmpty) continue;
      
      // Skip items with generic names
      if (name.toLowerCase().contains('x2 @') || 
          name.toLowerCase().contains('each') ||
          name.toLowerCase().contains('bag')) {
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
    
    // Convert to list and sort by total spent
    final products = productTotals.entries.map((entry) {
      return {
        'name': entry.key,
        'total': entry.value,
        'count': productCounts[entry.key] ?? 0,
      };
    }).toList();
    
    // Sort by count (most purchased)
    products.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    
    // Return top 4 or fewer if less than 4 products
    return products.take(4).toList();
  }
  
  // Get total spent by merchant
  List<Map<String, dynamic>> _getMerchantTotals() {
    if (_receiptHeaders.isEmpty) return [];
    
    // Group by merchant and calculate total spent
    final Map<String, double> merchantTotals = {};
    
    for (var receipt in _receiptHeaders) {
      final merchant = receipt['merchant']?.toString() ?? '';
      if (merchant.isEmpty) continue;
      
      double total = 0;
      if (receipt['total'] is double) {
        total = receipt['total'];
      } else if (receipt['total'] is String) {
        final totalStr = (receipt['total'] as String)
            .replaceAll('\$', '')
            .replaceAll('AUD', '');
        total = double.tryParse(totalStr) ?? 0;
      }
      
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
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
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
        final result = json.decode(response.body);
        setState(() { 
          _isSubmitted = true;
          _existingCsvFiles = result;
        });
        
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
}
