import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';
import 'analysis_result_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with TickerProviderStateMixin {
  XFile? _selectedImage;
  Uint8List? _webImageBytes; // used on web for preview
  final _descriptionCtrl = TextEditingController();
  bool _isAnalyzing = false;
  late AnimationController _analyzeAnimController;
  String _analyzingText = 'Analyzing vehicle issue...';
  String? _detectedArea; // Area name from Mappls reverse geocode

  @override
  void initState() {
    super.initState();
    _analyzeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _analyzeAnimController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImage = pickedFile;
          _webImageBytes = bytes;
        });
      } else {
        setState(() {
          _selectedImage = pickedFile;
          _webImageBytes = null;
        });
      }
    }
  }

  Future<Position?> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Enable location services for real nearby service centers'),
            duration: Duration(seconds: 3),
          ));
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location permission denied – grant it in settings for nearby results'),
            duration: Duration(seconds: 3),
          ));
        }
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      debugPrint('Location error: $e');
      return null;
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select an image first'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analyzingText = 'Getting your location...';
    });
    _analyzeAnimController.repeat();

    // Get user location for Mappls nearby search
    final position = await _getUserLocation();

    // Reverse geocode to show user's area name
    if (position != null && mounted) {
      final geo = await ApiService.reverseGeocode(position.latitude, position.longitude);
      final locality = geo['locality'] as String? ?? '';
      final city = geo['city'] as String? ?? '';
      final area = [locality, city].where((s) => s.isNotEmpty).join(', ');
      if (area.isNotEmpty && mounted) {
        setState(() {
          _detectedArea = area;
          _analyzingText = 'Location: $area';
        });
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }

    if (mounted && _isAnalyzing) {
      setState(() => _analyzingText = 'Uploading image...');
    }

    // Simulate progress text changes
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isAnalyzing) {
        setState(() => _analyzingText = 'AI is analyzing the image...');
      }
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isAnalyzing) {
        setState(() => _analyzingText = 'Detecting vehicle issues...');
      }
    });
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _isAnalyzing) {
        setState(() => _analyzingText = 'Searching nearby service centers...');
      }
    });

    try {
      final result = await ApiService.analyzeImage(
        imageFile: _selectedImage!,
        imageBytes: _webImageBytes,
        description: _descriptionCtrl.text.trim(),
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      if (!mounted) return;

      _analyzeAnimController.stop();
      setState(() => _isAnalyzing = false);

      if (result['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisResultScreen(scanData: result['data']),
          ),
        );
      } else {
        _showError(result['message'] ?? 'Analysis failed');
      }
    } catch (e) {
      if (mounted) {
        _analyzeAnimController.stop();
        setState(() => _isAnalyzing = false);
        _showError('Connection error. Please ensure the server is running.');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Vehicle Issue'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isAnalyzing ? _buildAnalyzingView() : _buildUploadView(),
    );
  }

  Widget _buildAnalyzingView() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.lightGradient),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated scanning effect
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring
                AnimatedBuilder(
                  animation: _analyzeAnimController,
                  builder: (context, child) {
                    return Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryColor
                              .withValues(alpha: 0.3 + _analyzeAnimController.value * 0.3),
                          width: 3,
                        ),
                      ),
                    );
                  },
                ),
                // Inner content
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.2),
                        AppTheme.accentColor.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    size: 50,
                    color: AppTheme.primaryColor,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(duration: 1500.ms, color: AppTheme.primaryLight),
              ],
            )
                .animate(onPlay: (c) => c.repeat())
                .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.05, 1.05),
                  duration: 1200.ms,
                  curve: Curves.easeInOut,
                ),
            const SizedBox(height: 40),
            Text(
              _analyzingText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                  ),
            ).animate().fadeIn(),
            const SizedBox(height: 16),
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: AppTheme.surfaceBg,
                valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This may take a few moments...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadView() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.lightGradient),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Upload Area
            GestureDetector(
              onTap: () => _showImageSourceDialog(),
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: _selectedImage != null
                        ? AppTheme.accentColor
                        : AppTheme.surfaceBg,
                    width: _selectedImage != null ? 2 : 1,
                  ),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLg - 1),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            kIsWeb && _webImageBytes != null
                                ? Image.memory(_webImageBytes!, fit: BoxFit.cover)
                                : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _selectedImage = null;
                                  _webImageBytes = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check, color: Colors.white,
                                        size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Image Selected',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_a_photo_rounded,
                              size: 48,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Upload Vehicle Photo',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Take a photo or choose from gallery',
                            style: TextStyle(
                              color: AppTheme.textMuted.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.1, end: 0),

            const SizedBox(height: 20),

            // Image source buttons
            Row(
              children: [
                Expanded(
                  child: _buildSourceButton(
                    Icons.camera_alt_rounded,
                    'Camera',
                    () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSourceButton(
                    Icons.photo_library_rounded,
                    'Gallery',
                    () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms),

            const SizedBox(height: 24),

            // Description Field
            Text(
              'Describe the issue (optional)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g., Strange smoke from engine, unusual noise...',
                filled: true,
                fillColor: AppTheme.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 16),

            // Detected location chip (shown after user picks image)
            if (_detectedArea != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.accentColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _detectedArea!,
                      style: const TextStyle(color: AppTheme.accentColor, fontSize: 13),
                    ),
                  ],
                ),
              ).animate().fadeIn(),

            const SizedBox(height: 32),

            // Analyze Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedImage != null ? _analyzeImage : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  disabledBackgroundColor: AppTheme.surfaceBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome,
                        color: _selectedImage != null
                            ? Colors.white
                            : AppTheme.textMuted),
                    const SizedBox(width: 10),
                    Text(
                      'Analyze Problem',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _selectedImage != null
                            ? Colors.white
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 500.ms, duration: 400.ms)
                .slideY(begin: 0.1, end: 0),

            const SizedBox(height: 24),

            // Tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: AppTheme.info, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'For best results, take a close-up, well-lit photo clearly showing the issue area.',
                      style: TextStyle(
                        color: AppTheme.info.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 700.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.surfaceBg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.lScaffoldBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose Image Source',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              ),
              title: const Text('Camera',
                  style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: const Text('Take a new photo',
                  style: TextStyle(color: AppTheme.textMuted)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const Divider(color: AppTheme.surfaceBg),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.photo_library, color: AppTheme.accentColor),
              ),
              title: const Text('Gallery',
                  style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: const Text('Choose from photo library',
                  style: TextStyle(color: AppTheme.textMuted)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
