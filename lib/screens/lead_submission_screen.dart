import 'package:flutter/material.dart';
import 'package:testestae/services/real_estate_bot_service.dart';


class LeadSubmissionScreen extends StatefulWidget {
  const LeadSubmissionScreen({Key? key}) : super(key: key);

  @override
  State<LeadSubmissionScreen> createState() => _LeadSubmissionScreenState();
}

class _LeadSubmissionScreenState extends State<LeadSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _botService = RealEstateBotService();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedLocation;
  String? _selectedPropertyType;
  String? _selectedPriceRange;

  bool _isSubmitting = false;

  final List<String> _locations = ['Pune', 'Nagpur', 'Nanded'];

  final List<String> _propertyTypes = ['Flat', 'House', 'Plot', 'Shop'];

  final List<String> _priceRanges = [
    'Under ₹20 Lakhs',
    '₹20 - ₹40 Lakhs',
    '₹40 - ₹60 Lakhs',
    '₹60 - ₹80 Lakhs',
    '₹80 Lakhs - ₹1 Crore',
    'Above ₹1 Crore',
  ];

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      await _botService.init();
    } catch (e) {
      _showError('Failed to initialize service: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitLead() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final success = await _botService.submitLead(
        fullName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        location: _selectedLocation!,
        propertyType: _selectedPropertyType!,
        priceRange: _selectedPriceRange!,
      );

      if (success) {
        _showSuccess();
        _clearForm();
      } else {
        _showError('Failed to submit lead. Please try again.');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _phoneController.clear();
    setState(() {
      _selectedLocation = null;
      _selectedPropertyType = null;
      _selectedPriceRange = null;
    });
  }

  void _showSuccess() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success!'),
        content: const Text(
          'Your details have been submitted successfully.\n\n'
              'Our AI assistant will call you within 5 minutes to discuss '
              'available properties that match your requirements.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Inquiry'),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Welcome message
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: const [
                      Icon(Icons.phone_in_talk, size: 48, color: Colors.blue),
                      SizedBox(height: 8),
                      Text(
                        'AI-Powered Property Assistance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Submit your details and our AI assistant will call you '
                            'to discuss properties matching your needs!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Full Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'Enter your full name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: '10-digit mobile number',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.length != 10) {
                    return 'Phone number must be 10 digits';
                  }
                  if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                    return 'Please enter only numbers';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Location
              DropdownButtonFormField<String>(
                value: _selectedLocation,
                decoration: const InputDecoration(
                  labelText: 'Location *',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                items: _locations.map((location) {
                  return DropdownMenuItem(
                    value: location,
                    child: Text(location),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedLocation = value);
                },
                validator: (value) {
                  if (value == null) return 'Please select a location';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Property Type
              DropdownButtonFormField<String>(
                value: _selectedPropertyType,
                decoration: const InputDecoration(
                  labelText: 'Property Type *',
                  prefixIcon: Icon(Icons.home),
                  border: OutlineInputBorder(),
                ),
                items: _propertyTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedPropertyType = value);
                },
                validator: (value) {
                  if (value == null) return 'Please select a property type';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Price Range
              DropdownButtonFormField<String>(
                value: _selectedPriceRange,
                decoration: const InputDecoration(
                  labelText: 'Price Range *',
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(),
                ),
                items: _priceRanges.map((range) {
                  return DropdownMenuItem(
                    value: range,
                    child: Text(range),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedPriceRange = value);
                },
                validator: (value) {
                  if (value == null) return 'Please select a price range';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitLead,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text(
                  'Submit & Get AI Call',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),

              const SizedBox(height: 16),

              // Info text
              const Text(
                '* Our AI assistant will call you within 5 minutes',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}