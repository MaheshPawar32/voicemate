import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/ads/ad_ids.dart';
import '../../services/admob_service.dart';

class HomeBannerAd extends StatefulWidget {
  const HomeBannerAd({super.key});

  @override
  State<HomeBannerAd> createState() => _HomeBannerAdState();
}

class _HomeBannerAdState extends State<HomeBannerAd> {
  BannerAd? _banner;
  bool _loading = false;

  String get _adUnitId => AdIds.banner;

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  void _loadBanner() {
    if (_loading || _banner != null || _adUnitId.isEmpty) return;
    _loading = true;

    final banner = BannerAd(
      adUnitId: _adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _banner = ad as BannerAd;
            _loading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _loading = false;
              _banner = null;
            });
          }
        },
      ),
    );

    banner.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: AdMobService.instance,
        builder: (context, _) {
          final service = AdMobService.instance;
          if (!service.initialized ||
              !service.canRequestAds ||
              _adUnitId.isEmpty) {
            if (_banner != null) {
              final previous = _banner;
              _banner = null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                previous?.dispose();
              });
            }
            return const SizedBox.shrink();
          }
          if (_banner == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadBanner();
            });
            return const SizedBox.shrink();
          }
          return SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: _banner!.size.height.toDouble(),
              child: Center(child: AdWidget(ad: _banner!)),
            ),
          );
        },
      );
}
