import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../utils/app_logger.dart';

/// Profile page for viewing and editing user information (with home address for parent app)
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileService _profileService = ProfileService();

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  UserProfile? _currentProfile;
  UserProfile? _originalProfile;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();

    // Track changes
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _profileService.fetchProfile();

      if (profile == null) {
        setState(() {
          _errorMessage = 'Could not load profile. Please try again.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _currentProfile = profile;
        _originalProfile = profile;
        _firstNameController.text = profile.firstName ?? '';
        _lastNameController.text = profile.lastName ?? '';
        _emailController.text = profile.email ?? '';
        // Home address fields would be loaded here if stored in profile
        _isLoading = false;
        _hasChanges = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile: $e';
        _isLoading = false;
      });
      logger.error('[PROFILE] Failed to load profile: $e');
    }
  }

  void _onFieldChanged() {
    final hasChanges =
        _firstNameController.text.trim() !=
            (_originalProfile?.firstName ?? '') ||
        _lastNameController.text.trim() != (_originalProfile?.lastName ?? '') ||
        _emailController.text.trim() != (_originalProfile?.email ?? '');

    if (hasChanges != _hasChanges) {
      setState(() => _hasChanges = hasChanges);
    }
  }

  Future<void> _showConfirmationDialog() async {
    final changes = <String>[];

    if (_firstNameController.text.trim() !=
        (_originalProfile?.firstName ?? '')) {
      changes.add(
          '• First Name: "${_originalProfile?.firstName ?? '(empty)'}" → "${_firstNameController.text.trim()}"');
    }
    if (_lastNameController.text.trim() != (_originalProfile?.lastName ?? '')) {
      changes.add(
          '• Last Name: "${_originalProfile?.lastName ?? '(empty)'}" → "${_lastNameController.text.trim()}"');
    }
    if (_emailController.text.trim() != (_originalProfile?.email ?? '')) {
      changes.add(
          '• Email: "${_originalProfile?.email ?? '(empty)'}" → "${_emailController.text.trim()}"');
    }

    if (changes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Profile?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The following changes will be saved:'),
              const SizedBox(height: 12),
              ...changes.map(
                (change) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(change, style: const TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _saveProfile();
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final success = await _profileService.updateProfile(
        profId: _currentProfile!.profId,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload to get fresh data
        await _loadProfile();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      logger.error('[PROFILE] Failed to save profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _cancelChanges() {
    setState(() {
      _firstNameController.text = _originalProfile?.firstName ?? '';
      _lastNameController.text = _originalProfile?.lastName ?? '';
      _emailController.text = _originalProfile?.email ?? '';
      _hasChanges = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildProfileForm(),
    );
  }

  Widget _buildProfileForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Icon
            const Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),

            // Personal Information Section
            const Text(
              'Personal Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Phone Number (read-only)
            _buildReadOnlyField(
              label: 'Phone Number',
              value: _currentProfile?.phoneNumber ?? '',
              icon: Icons.phone,
            ),
            const SizedBox(height: 16),

            // First Name
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'First Name',
                hintText: 'Enter your first name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Last Name
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Last Name',
                hintText: 'Enter your last name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                hintText: 'Enter your email address',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  final emailRegex = RegExp(
                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                  );
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Please enter a valid email address';
                  }
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Action Buttons with SafeArea
            SafeArea(
              child: Row(
              children: [
                // Cancel button
                Expanded(
                  child: OutlinedButton(
                    onPressed: _hasChanges ? _cancelChanges : null,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                // Save button
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_hasChanges && !_isSaving)
                        ? _showConfirmationDialog
                        : null,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
              ],
            ),
            ), // SafeArea
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
