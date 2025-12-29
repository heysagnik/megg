import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../widgets/loader.dart';
import 'ai_results_screen.dart';

class AICameraScreen extends StatefulWidget {
  const AICameraScreen({super.key});

  @override
  State<AICameraScreen> createState() => _AICameraScreenState();
}

class _AICameraScreenState extends State<AICameraScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _flashOn = false;
  bool _showOnboardingTip = false; //TODO false

  static const String _onboardingSeenKey = 'ai_camera_onboarding_seen';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool(_onboardingSeenKey) ?? false;
    if (!hasSeen && mounted) {
      setState(() => _showOnboardingTip = true);
    }
  }

  Future<void> _dismissOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
    if (mounted) {
      setState(() => _showOnboardingTip = false);
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _cameraController = CameraController(
          _cameras.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() => _isInitialized = true);
        }
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    
    setState(() => _flashOn = !_flashOn);
    await _cameraController!.setFlashMode(
      _flashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<File?> _cropImage(File imageFile) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'CROP',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            statusBarColor: Colors.black,
            backgroundColor: Colors.black,
            activeControlsWidgetColor: Colors.white,
            cropFrameColor: Colors.white,
            cropGridColor: Colors.white.withOpacity(0.2),
            dimmedLayerColor: Colors.black.withOpacity(0.7),
            cropFrameStrokeWidth: 1,
            showCropGrid: false,
            lockAspectRatio: false,
            hideBottomControls: true,
            initAspectRatio: CropAspectRatioPreset.original,
          ),
          IOSUiSettings(
            title: 'CROP',
            cancelButtonTitle: 'CANCEL',
            doneButtonTitle: 'DONE',
            resetButtonHidden: true,
            rotateButtonsHidden: true,
            aspectRatioPickerButtonHidden: true,
            rotateClockwiseButtonHidden: true,
          ),
        ],
      );
      
      if (croppedFile != null) {
        return File(croppedFile.path);
      }
      return null;
    } catch (e) {
      debugPrint('Crop error: $e');
      // If cropping fails, return original image
      return imageFile;
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || _isProcessing) return;

    try {
      final XFile image = await _cameraController!.takePicture();
      
      // Turn off flash after capture
      if (_flashOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
        setState(() => _flashOn = false);
      }
      
      // Show crop dialog
      final croppedFile = await _cropImage(File(image.path));
      if (croppedFile == null) return; // User cancelled
      
      if (!mounted) return;
      setState(() => _isProcessing = true);
      await _analyzeImage(croppedFile);
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        _showError('Failed to capture image');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        // Show crop dialog
        final croppedFile = await _cropImage(File(image.path));
        if (croppedFile == null) return; // User cancelled
        
        if (!mounted) return;
        setState(() => _isProcessing = true);
        await _analyzeImage(croppedFile);
      }
    } catch (e) {
      debugPrint('Gallery pick error: $e');
      if (mounted) {
        _showError('Failed to select image');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _analyzeImage(File imageFile) async {
    try {
      final result = await AIService().analyzeImage(imageFile);
      
      if (!mounted) return;
      
      // Navigate to results screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AIResultsScreen(
            uploadedImage: imageFile,
            result: result,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Analysis error: $e');
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen Camera Preview
          if (_isInitialized && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(
              child: Loader(color: Colors.white),
            ),

          // Top bar - Close and Flash
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          PhosphorIconsRegular.x,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    // Flash toggle
                    GestureDetector(
                      onTap: _toggleFlash,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _flashOn
                              ? PhosphorIconsFill.lightning
                              : PhosphorIconsRegular.lightning,
                          color: _flashOn ? Colors.yellow : Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Gallery picker
                    GestureDetector(
                      onTap: _isProcessing ? null : _pickFromGallery,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          PhosphorIconsRegular.images,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 40),
                    
                    // Capture button (center)
                    GestureDetector(
                      onTap: _isProcessing ? null : _captureImage,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isProcessing
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 40),
                    
                    // Placeholder for symmetry
                    const SizedBox(width: 52, height: 52),
                  ],
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated loader
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Animated text
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: child,
                          );
                        },
                        child: const Column(
                          children: [
                            Text(
                              'MEGHANSH',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 6,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'IS FINDING THE BEST CHOICE FOR YOU',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Onboarding Tooltip (first-time users)
          if (_showOnboardingTip && !_isProcessing)
            Positioned.fill(
              child: GestureDetector(
                onTap: _dismissOnboarding,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated entrance
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutBack,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Opacity(
                                opacity: value.clamp(0.0, 1.0),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 32),
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                const Center(
                                  child: Text(
                                    'FIND YOUR PERFECT MATCH',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 2,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Introduction
                                Text(
                                  'Have a pink shirt but don\'t know which jeans color to wear with it? Just upload a photo in our MEGG Camera.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: Colors.grey[700],
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // What it does section
                                const Text(
                                  'What it does:',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildBulletPoint('Upload a shirt → get best jeans / pants colors'),
                                _buildBulletPoint('Upload jeans → get best shirt / upper colors'),
                                _buildBulletPoint('See all matching color options'),
                                _buildBulletPoint('Get product links that look damn good together'),
                                const SizedBox(height: 16),
                                // How to use
                                Text(
                                  'Use it anytime.\nUpload any clothing item.\nWe suggest the best color combination.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Key benefit
                                const Center(
                                  child: Text(
                                    'One photo → All matching colors → Buy links',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    'No thinking. No confusion.\nJust perfect matching.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // CTA Button
                                Container(
                                  width: double.infinity,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'GOT IT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
