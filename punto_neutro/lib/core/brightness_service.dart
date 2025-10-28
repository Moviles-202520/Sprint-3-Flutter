import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Content type to tune brightness against
enum ContentMode { news, comments, rating }

/// BrightnessService
/// - Computes a context-aware brightness level (0..1)
///   considering time of day and content type.
/// - Exposes a ValueNotifier so UI can reactively overlay dimming.
class BrightnessService {
  BrightnessService._();
  static final BrightnessService _instance = BrightnessService._();
  factory BrightnessService() => _instance;
  static BrightnessService get instance => _instance;

  final ValueNotifier<double> level = ValueNotifier<double>(1.0);
  ContentMode _mode = ContentMode.news;

  /// Expose current mode for UI decisions (read-only)
  ContentMode get mode => _mode;
  /// A notifier for mode changes so UI can rebuild when mode switches.
  final ValueNotifier<ContentMode> modeNotifier = ValueNotifier(ContentMode.news);

  /// Update brightness based on the current content being shown.
  void setMode(ContentMode mode) {
    // debug
    // ignore: avoid_print
    print('🔆 [BRIGHTNESS] setMode -> $mode');
    _mode = mode;
    modeNotifier.value = mode;
    _recompute();
  }

  /// Recompute brightness based on time and mode.
  void _recompute() {
    final now = DateTime.now();
    final hour = now.hour;
    final isDay = hour >= 7 && hour < 19; // Day: 7AM-7PM

    // Stronger defaults so the dim is clearly visible when focusing inputs
    double base = isDay ? 1.0 : 0.95;

    switch (_mode) {
      case ContentMode.news:
        // no change
        break;
      case ContentMode.comments:
        // Strong dim when commenting
        base -= isDay ? 0.55 : 0.65;
        break;
      case ContentMode.rating:
        // Moderate dim when rating
        base -= isDay ? 0.45 : 0.55;
        break;
    }

    // Clamp to [0.2, 1.0] to avoid fully dark screens
    final next = base.clamp(0.2, 1.0);
    // Avoid notifying listeners synchronously during the build phase which can
    // cause "setState() or markNeedsBuild() called during build" exceptions.
    // Schedule the value change for the next frame if we're in build.
    if (level.value != next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Double-check in the callback in case value changed again.
        if (level.value != next) level.value = next;
      });
    }
  }
}

/// Widget overlay that applies dimming based on BrightnessService.level.
class BrightnessOverlay extends StatelessWidget {
  final Widget child;
  const BrightnessOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: BrightnessService.instance.level,
      builder: (context, value, _) {
        // ignore: avoid_print
        print('🔆 [BRIGHTNESS] overlay value: $value');
        final opacity = (1.0 - value).clamp(0.0, 0.7); // cap overlay opacity
        return Stack(
          children: [
            child,
            // Ensure the overlay fills the whole Stack area. Use Positioned.fill
            // as a direct child of Stack so ParentData is applied correctly.
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  color: Colors.black.withOpacity(opacity),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
