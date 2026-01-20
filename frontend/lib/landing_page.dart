import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

class LandingPage extends StatelessWidget {
  final VoidCallback onGetStarted;
  
  const LandingPage({super.key, required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Icon
                  Icon(
                    Icons.receipt_long,
                    size: 80,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    'Receipt Automation',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Subtitle
                  Text(
                    'Turn receipts into accounting-ready data',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Features
                  _buildFeature(Icons.camera_alt, 'Upload receipt images'),
                  const SizedBox(height: 16),
                  _buildFeature(Icons.auto_awesome, 'AI extracts all data automatically'),
                  const SizedBox(height: 16),
                  _buildFeature(Icons.edit, 'Review and edit before saving'),
                  const SizedBox(height: 16),
                  _buildFeature(Icons.download, 'Export to CSV for accounting'),
                  const SizedBox(height: 48),
                  
                  // CTA Button
                  ElevatedButton(
                    onPressed: () {
                      // Redirect to app subdomain if on root domain
                      if (kIsWeb) {
                        final hostname = html.window.location.hostname ?? '';
                        if (hostname == 'yourreceipt.online') {
                          html.window.location.href = 'https://app.yourreceipt.online';
                        } else {
                          onGetStarted();
                        }
                      } else {
                        onGetStarted();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Secondary text
                  Text(
                    'Free to use • No credit card required',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Privacy note
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Your data stays with you. We don\'t store any receipt data on our servers.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green.shade900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Contact email
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.email, color: Colors.grey.shade600, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Contact: info at intelligentcloud.com.au',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFeature(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.blue.shade600, size: 28),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(fontSize: 18, color: Colors.black87),
        ),
      ],
    );
  }
}
