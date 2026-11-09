import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../models/address_model.dart';
import '../providers/address_provider.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  final _houseNoController = TextEditingController();
  final _areaController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedTag = 'Home';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final userName = auth?.profile?.fullName;
    if (userName != null && userName.trim().isNotEmpty) {
      _nameController.text = userName.trim();
    }
  }

  @override
  void dispose() {
    _houseNoController.dispose();
    _areaController.dispose();
    _landmarkController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    final newAddress = AddressModel(
      id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
      tag: _selectedTag,
      houseNo: _houseNoController.text.trim(),
      area: _areaController.text.trim(),
      landmark: _landmarkController.text.trim(),
      recipientName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      deliveryTimeMinutes: _selectedTag == 'Home'
          ? 5
          : (_selectedTag == 'Work' ? 8 : 10),
      isDefault: false,
    );

    setState(() => _isSaving = true);
    try {
      await context.read<AddressProvider>().addAddress(newAddress);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Address "${newAddress.shortDisplay}" saved and selected.',
          ),
          backgroundColor: AppColors.badgeGreen,
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save this address: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Add Delivery Address',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Map / Location preview banner
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.giftBannerBg,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.accentPink,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivering in 5-10 minutes',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Zepto Instant Dark Store nearby',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Form container
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SAVE ADDRESS AS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Tag selector chips
                    Row(
                      children: [
                        _buildTagOption('Home', Icons.home_rounded),
                        const SizedBox(width: 8),
                        _buildTagOption('Work', Icons.work_rounded),
                        const SizedBox(width: 8),
                        _buildTagOption('Other', Icons.location_on_rounded),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // House / Flat No
                    _buildTextField(
                      controller: _houseNoController,
                      label: 'Flat / House No / Building Name *',
                      hint: 'e.g. Flat 302, Green Valley Apts',
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Please enter house/flat no'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Area / Sector
                    _buildTextField(
                      controller: _areaController,
                      label: 'Area / Street / Sector *',
                      hint: 'e.g. Madhapur, Hitech City',
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Please enter area/street'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Landmark
                    _buildTextField(
                      controller: _landmarkController,
                      label: 'Nearby Landmark (Optional)',
                      hint: 'e.g. Next to Metro Station',
                    ),
                    const SizedBox(height: 20),

                    const Divider(height: 1, color: Color(0xFFF0EBF4)),
                    const SizedBox(height: 16),

                    const Text(
                      'RECIPIENT DETAILS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Name
                    _buildTextField(
                      controller: _nameController,
                      label: 'Receiver Name *',
                      hint: 'Your full name',
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Please enter name'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Phone
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number *',
                      hint: 'e.g. +91 98765 43210',
                      keyboardType: TextInputType.phone,
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Please enter phone'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save & Deliver Here',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagOption(String tag, IconData icon) {
    final isSelected = _selectedTag == tag;

    return InkWell(
      onTap: () => setState(() => _selectedTag = tag),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentPinkSoft
              : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accentPink : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.accentPink
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              tag,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? AppColors.accentPink
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            filled: true,
            fillColor: const Color(0xFFF9F8FA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.accentPink,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
