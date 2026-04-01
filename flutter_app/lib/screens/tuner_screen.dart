import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  double? _pitch;
  String _note = '--';
  int _cents = 0;
  int _activeString = 1;
  bool _isListening = false;



  void _startTuning() {
    // Note: Real pitch detection requires platform-specific microphone access
    // For now, show the UI in demo mode
    setState(() {
      _isListening = true;
      _note = _activeString == 1 ? 'G3' : 'D3';
      _pitch = _activeString == 1 ? 196.0 : 146.8;
      _cents = 3; // Slightly off for demo
    });
  }

  bool get _isInTune => _cents.abs() < 5;

  String _getStatusHint() {
    final t = context.read<AppProvider>().t;
    if (_pitch == null) return t.playAString;
    if (_isInTune) return t.perfectTune;
    return _cents > 0 ? t.tuneDown : t.tightenSlightly;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final t = provider.t;

    return Scaffold(
      body: Stack(
        children: [
          // Background glow
          Center(
            child: AnimatedContainer(
              duration: const Duration(seconds: 1),
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isInTune
                    ? AppColors.emerald.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      onPressed: () =>
                          provider.navigateTo(AppScreen.library),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    const SizedBox(width: 12),
                    Text(t.precisionTuner, style: serifBold(22)),
                    const Spacer(),
                    if (!_isListening)
                      ElevatedButton.icon(
                        onPressed: _startTuning,
                        icon: const Icon(Icons.mic, size: 20),
                        label: Text(t.startListening),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                  ],
                ),

                const Spacer(),

                // Note Display
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    letterSpacing: -4,
                    color: _isInTune ? AppColors.emerald : Colors.white,
                  ),
                  child: Text(_note),
                ),
                const SizedBox(height: 8),
                Text(
                  _pitch != null ? '${_pitch!.round()} Hz' : '-- Hz',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 13,
                      fontFamily: 'monospace',
                      letterSpacing: 4),
                ),

                const SizedBox(height: 48),

                // Cents Scale
                SizedBox(
                  width: 500,
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Track
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          // Center mark
                          Container(
                            width: 2,
                            height: 32,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          // Needle
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            left: 250 + _cents * 5 - 2,
                            child: Column(
                              children: [
                                Container(
                                  width: 4,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    color: _isInTune
                                        ? AppColors.emerald
                                        : Colors.white,
                                    boxShadow: _isInTune
                                        ? [
                                            BoxShadow(
                                              color: AppColors.emerald
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 12,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _cents > 0 ? '+$_cents' : '$_cents',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: _isInTune
                                          ? AppColors.emerald
                                          : Colors.white.withValues(alpha: 0.4)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('-50 CENTS',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                  color: Colors.white.withValues(alpha: 0.2))),
                          Text('+50 CENTS',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                  color: Colors.white.withValues(alpha: 0.2))),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Status hint
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: _isInTune ? AppColors.emerald : Colors.white.withValues(alpha: 0.6),
                  ),
                  child: Text(_getStatusHint()),
                ),

                if (_pitch != null && !_isInTune) ...[
                  const SizedBox(height: 16),
                  Icon(
                    _cents > 0 ? Icons.arrow_downward : Icons.arrow_upward,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 32,
                  ),
                ],

                const Spacer(),

                // String Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StringButton(
                      label: t.upperString,
                      reference: 'G ${t.reference}',
                      active: _activeString == 1,
                      onTap: () => setState(() {
                        _activeString = 1;
                        if (_isListening) _startTuning();
                      }),
                    ),
                    const SizedBox(width: 24),
                    _StringButton(
                      label: t.lowerString,
                      reference: 'D ${t.reference}',
                      active: _activeString == 2,
                      onTap: () => setState(() {
                        _activeString = 2;
                        if (_isListening) _startTuning();
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StringButton extends StatelessWidget {
  final String label;
  final String reference;
  final bool active;
  final VoidCallback onTap;

  const _StringButton({
    required this.label,
    required this.reference,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: active ? Colors.white : Colors.white.withValues(alpha: 0.1)),
          boxShadow: active
              ? [
                  const BoxShadow(
                    color: Colors.white24,
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.black : Colors.white.withValues(alpha: 0.4))),
            const SizedBox(height: 4),
            Text(reference,
                style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                    color: active
                        ? Colors.black.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.3))),
          ],
        ),
      ),
    );
  }
}



