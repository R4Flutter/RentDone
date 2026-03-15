import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rentdone/app/app_theme.dart';

class TenantTrustScoreScreen extends StatefulWidget {
  const TenantTrustScoreScreen({super.key});

  @override
  State<TenantTrustScoreScreen> createState() => _TenantTrustScoreScreenState();
}

class _TenantTrustScoreScreenState extends State<TenantTrustScoreScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _phoneController = TextEditingController();
  late final AnimationController _bgController;

  bool _isButtonPressed = false;
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  TenantTrustProfile? _result;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final normalized = _normalizeIndianPhone(_phoneController.text);

    if (normalized == null || !_isValidIndianLocalPhone(normalized)) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit Indian phone number.';
        _result = null;
        _hasSearched = true;
      });
      return;
    }

    final phoneDocId = '+91$normalized';

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final doc = await _firestore.collection('tenants').doc(phoneDocId).get();

      DocumentSnapshot<Map<String, dynamic>> effectiveDoc = doc;
      if (!doc.exists) {
        final localDoc = await _firestore
            .collection('tenants')
            .doc(normalized)
            .get();
        if (localDoc.exists) {
          effectiveDoc = localDoc;
        }
      }

      if (!effectiveDoc.exists) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Tenant record not found.';
          _result = null;
        });
        return;
      }

      final data = effectiveDoc.data() ?? <String, dynamic>{};
      final phoneFromDoc =
          (data['phone'] as String?) ??
          (data['phoneNumber'] as String?) ??
          effectiveDoc.id;

      if (!mounted) return;

      setState(() {
        _result = TenantTrustProfile.fromMap(
          id: effectiveDoc.id,
          data: data,
          fallbackPhone: phoneFromDoc,
        );
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Unable to fetch trust score right now. Please try again.';
        _result = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _normalizeIndianPhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return digits;
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    return null;
  }

  bool _isValidIndianLocalPhone(String value) {
    return RegExp(r'^[6-9][0-9]{9}$').hasMatch(value);
  }

  String _riskLabel(int score) {
    if (score >= 80) return 'Trusted Tenant';
    if (score >= 60) return 'Moderate Risk';
    return 'High Risk';
  }

  Color _riskColor(int score) {
    if (score >= 80) return AppTheme.successGreen;
    if (score >= 60) return AppTheme.warningAmber;
    return AppTheme.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          final t = _bgController.value;

          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [
                        AppTheme.nearBlack,
                        AppTheme.darkBackground,
                      ],
                    ),
                  ),
                ),
              ),
              _floatingBubble(
                bottom: -70 + (t * 16),
                right: -46 + (t * 12),
                size: 260,
                blurSigma: 90,
                opacity: 0.20,
                colors: const [AppTheme.liquidPrimaryStart, AppTheme.infoBlue],
              ),
              _floatingBubble(
                bottom: -52 - (t * 12),
                left: -34 + (t * 8),
                size: 180,
                blurSigma: 70,
                opacity: 0.15,
                colors: const [AppTheme.liquidPrimaryEnd, AppTheme.primaryBlue],
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopGlassBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 18),
                            _buildSearchCard(),
                            const SizedBox(height: 14),
                            _buildSearchButton(),
                            const SizedBox(height: 20),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 320),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: _buildResultState(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopGlassBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite.withOpacity(0.05),
            border: Border(
              bottom: BorderSide(color: AppTheme.pureWhite.withOpacity(0.12)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
                icon: const Icon(Icons.menu_rounded, color: AppTheme.pureWhite),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.home_work_rounded,
                      size: 18,
                      color: AppTheme.infoBlue,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'RentDone',
                      style: TextStyle(
                        color: AppTheme.pureWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.pureWhite.withOpacity(0.09),
                  border: Border.all(
                    color: AppTheme.pureWhite.withOpacity(0.18),
                  ),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: AppTheme.pureWhite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'Tenant Trust Score',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppTheme.pureWhite,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Check tenant trust score using phone number',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.darkTextSecondary.withOpacity(0.82),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite.withOpacity(0.06),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.pureWhite.withOpacity(0.14)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.20),
                blurRadius: 20,
                spreadRadius: -3,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppTheme.pureWhite.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.pureWhite.withOpacity(0.10),
                      ),
                    ),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.search,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                        LengthLimitingTextInputFormatter(14),
                      ],
                      style: const TextStyle(
                        color: AppTheme.pureWhite,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Phone Number',
                        hintStyle: TextStyle(
                          color: AppTheme.darkTextSecondary.withOpacity(0.78),
                        ),
                        prefixIcon: Icon(
                          Icons.phone_rounded,
                          color: AppTheme.infoBlue.withOpacity(0.95),
                        ),
                      ),
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter tenant phone number to check trust score',
                style: TextStyle(
                  color: AppTheme.darkTextSecondary.withOpacity(0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return AnimatedScale(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      scale: _isButtonPressed ? 0.97 : 1,
      child: SizedBox(
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [AppTheme.liquidPrimaryStart, AppTheme.infoBlue],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.30),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: GestureDetector(
                onTapDown: _isLoading
                    ? null
                    : (_) => setState(() => _isButtonPressed = true),
                onTapUp: _isLoading
                    ? null
                    : (_) => setState(() => _isButtonPressed = false),
                onTapCancel: _isLoading
                    ? null
                    : () => setState(() => _isButtonPressed = false),
                onTap: _isLoading ? null : _search,
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.pureWhite,
                            ),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: AppTheme.pureWhite,
                              size: 19,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Search Trust Score',
                              style: TextStyle(
                                color: AppTheme.pureWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultState() {
    if (_isLoading) {
      return const _LoadingSkeleton(key: ValueKey('loading'));
    }
    if (_errorMessage != null) {
      return _WarningCard(
        key: const ValueKey('warning'),
        message: _errorMessage!,
      );
    }
    if (_result != null) {
      return _ResultCard(
        key: const ValueKey('result'),
        profile: _result!,
        riskLabel: _riskLabel(_result!.trustScore),
        riskColor: _riskColor(_result!.trustScore),
      );
    }
    if (!_hasSearched) {
      return const _EmptyState(key: ValueKey('empty'));
    }
    return const _EmptyState(
      key: ValueKey('empty-after'),
      message: 'No tenant searched yet',
    );
  }

  Widget _floatingBubble({
    double? top,
    double? left,
    double? bottom,
    double? right,
    required double size,
    required double blurSigma,
    required double opacity,
    required List<Color> colors,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TenantTrustProfile {
  const TenantTrustProfile({
    required this.name,
    required this.phone,
    required this.city,
    required this.trustScore,
    required this.totalRentals,
    required this.latePayments,
    required this.disputes,
    required this.verified,
  });

  final String name;
  final String phone;
  final String city;
  final int trustScore;
  final int totalRentals;
  final int latePayments;
  final int disputes;
  final bool verified;

  factory TenantTrustProfile.fromMap({
    required String id,
    required Map<String, dynamic> data,
    required String fallbackPhone,
  }) {
    final score = ((data['trustScore'] as num?)?.toInt() ?? 0).clamp(0, 100);
    return TenantTrustProfile(
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : (data['fullName'] as String?)?.trim().isNotEmpty == true
          ? (data['fullName'] as String).trim()
          : 'Tenant',
      phone:
          (data['phone'] as String?) ??
          (data['phoneNumber'] as String?) ??
          fallbackPhone,
      city: (data['city'] as String?)?.trim().isNotEmpty == true
          ? (data['city'] as String).trim()
          : 'Unknown City',
      trustScore: score,
      totalRentals: (data['totalRentals'] as num?)?.toInt() ?? 0,
      latePayments: (data['latePayments'] as num?)?.toInt() ?? 0,
      disputes: (data['disputes'] as num?)?.toInt() ?? 0,
      verified: data['verified'] == true,
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    super.key,
    required this.profile,
    required this.riskLabel,
    required this.riskColor,
  });

  final TenantTrustProfile profile;
  final String riskLabel;
  final Color riskColor;

  @override
  Widget build(BuildContext context) {
    final progress = profile.trustScore / 100;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) {
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 18),
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.pureWhite.withOpacity(0.07),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.pureWhite.withOpacity(0.14)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.16),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.pureWhite.withOpacity(0.10),
                        border: Border.all(
                          color: AppTheme.pureWhite.withOpacity(0.18),
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppTheme.pureWhite,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.pureWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.phone,
                            style: TextStyle(
                              color: AppTheme.darkTextSecondary.withOpacity(
                                0.92,
                              ),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.city,
                            style: TextStyle(
                              color: AppTheme.darkTextSecondary.withOpacity(
                                0.82,
                              ),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (profile.verified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppTheme.successGreen.withOpacity(0.45),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 14,
                              color: AppTheme.successGreen,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Verified',
                              style: TextStyle(
                                color: AppTheme.successGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.pureWhite.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.pureWhite.withOpacity(0.10),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trust Score: ${profile.trustScore} / 100',
                        style: const TextStyle(
                          color: AppTheme.pureWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return LinearProgressIndicator(
                              value: value,
                              minHeight: 9,
                              backgroundColor: AppTheme.pureWhite.withOpacity(
                                0.10,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                riskColor,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Total Rentals',
                        value: '${profile.totalRentals}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Late Payments',
                        value: '${profile.latePayments}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Disputes',
                        value: '${profile.disputes}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: riskColor.withOpacity(0.60)),
                    ),
                    child: Text(
                      riskLabel,
                      style: TextStyle(
                        color: riskColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.pureWhite.withOpacity(0.10)),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.pureWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.darkTextSecondary.withOpacity(0.82),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.warningAmber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.warningAmber.withOpacity(0.50)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.warningAmber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.warningAmber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key, this.message = 'No tenant searched yet'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.pureWhite.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.search_rounded,
                size: 42,
                color: AppTheme.darkTextSecondary.withOpacity(0.85),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.darkTextSecondary.withOpacity(0.90),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget block({double height = 16, double? width}) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: AppTheme.pureWhite.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.pureWhite.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.pureWhite.withOpacity(0.10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        block(height: 16, width: 130),
                        const SizedBox(height: 8),
                        block(height: 14, width: 95),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              block(height: 14),
              const SizedBox(height: 10),
              block(height: 42),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: block(height: 62)),
                  const SizedBox(width: 8),
                  Expanded(child: block(height: 62)),
                  const SizedBox(width: 8),
                  Expanded(child: block(height: 62)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
