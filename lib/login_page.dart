import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'OtpService.dart';
import 'home_page.dart';
import 'main.dart'; // To access storageService
import 'widgets/status_widget.dart';
import 'services/backend_com_service.dart';
import 'utils/app_logger.dart';

// Store verification ID here
String? verificationId;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final TextEditingController ngrokController = TextEditingController();
  bool otpSent = false;
  final String _countryCode = '+91'; // Fixed country code

  @override
  void initState() {
    super.initState();
    // No need to set phoneController.text since country code is separate
  }

  /// Request location permission if not already granted
  Future<void> _requestLocationPermissionIfNeeded() async {
    try {
      // Check if permission is already stored in Hive
      final savedPermission = storageService.getLocationPermission();

      if (savedPermission == true) {
        logger.debug(
          '[PERMISSION] Location permission already granted (from Hive)',
        );
        return;
      }

      logger.debug('[PERMISSION] Checking location permission...');

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        logger.debug('[PERMISSION] Requesting location permission...');
        permission = await Geolocator.requestPermission();
      }

      // Save permission status to Hive
      final granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;

      await storageService.saveLocationPermission(granted);

      logger.debug(
        '[PERMISSION] Location permission status: $permission (granted: $granted)',
      );

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission permanently denied. Please enable in app settings for trip tracking.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission denied. Trip tracking may not work properly.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      logger.error(
        '[PERMISSION ERROR] Error requesting location permission: $e stacktrace: $stackTrace',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTP Login')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!otpSent) ...[
                    Text(
                      'Enter Backend URL',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: ngrokController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: 'Backend URL',
                        hintText: 'Backend server',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Enter Phone Number',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Country code dropdown (non-editable, India only)
                        SizedBox(
                          height: 56,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _countryCode,
                                isDense: true,
                                items: [
                                  DropdownMenuItem(
                                    value: '+91',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '🇮🇳',
                                          style: TextStyle(fontSize: 20),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '+91',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: null, // Disable changing
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        // Phone number field
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                hintText: 'XXXXXXXXXX',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        // Use entered URL or default if empty
                        final backendUrl = ngrokController.text.trim().isEmpty
                            ? 'https://api.lusidlogix.com'
                            : ngrokController.text.trim();

                        final otpService = OtpService(backendUrl: backendUrl);
                        // Concatenate country code with phone number
                        final fullPhoneNumber =
                            _countryCode + phoneController.text.trim();
                        await otpService.sendOtp(
                          phoneNumber: fullPhoneNumber,
                          onCodeSent: (id) {
                            setState(() {
                              verificationId = id;
                              otpSent = true;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('OTP Sent Successfully'),
                              ),
                            );
                          },
                          onFailed: (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.message}')),
                            );
                          },
                        );
                      },
                      child: const Text('Send OTP'),
                    ),
                  ] else ...[
                    const Text(
                      'Enter OTP',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'OTP',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        if (verificationId != null) {
                          // Use entered URL or default if empty
                          final backendUrl = ngrokController.text.trim().isEmpty
                              ? 'https://api.lusidlogix.com'
                              : ngrokController.text.trim();

                          final otpService = OtpService(backendUrl: backendUrl);
                          await otpService.verifyOtp(
                            verificationId: verificationId!,
                            smsCode: otpController.text.trim(),
                            onBackendValidated: () async {
                              // Save backend URL to Hive
                              await storageService.saveNgrokUrl(backendUrl);

                              // Save login timestamp for session management
                              await storageService.saveLoginTimestamp(
                                DateTime.now(),
                              );

                              // Update global backend URL
                              BackendComService.instance.setBaseUrl(backendUrl);

                              // Request location permission after successful login
                              await _requestLocationPermissionIfNeeded();

                              showMessageInStatus(
                                "success",
                                "Login Successful",
                              );

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Login successful! Groups synced.',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );

                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => const HomePage(),
                                  ),
                                );
                              }
                            },
                            onBackendFailed: (error) {
                              showMessageInStatus("error", "Login Failed");

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Verification Failed: $error'),
                                  duration: const Duration(seconds: 10),
                                ),
                              );
                            },
                          );
                        }
                      },
                      child: const Text('Verify'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          otpSent = false;
                          verificationId = null;
                        });
                      },
                      child: const Text('Change Phone Number'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const CustomStatusWidget(),
        ],
      ),
    );
  }
}
