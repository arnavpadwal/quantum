import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/storage_service.dart';
import '../services/p2p_service.dart';
import 'dart:convert';

class ShareContactScreen extends StatefulWidget {
  const ShareContactScreen({super.key});

  @override
  State<ShareContactScreen> createState() => _ShareContactScreenState();
}

class _ShareContactScreenState extends State<ShareContactScreen> {
  String? _qrData;

  @override
  void initState() {
    super.initState();
    P2PService.instance.myIpv6AddressNotifier.addListener(_generateQrData);
    _generateQrData();
  }

  @override
  void dispose() {
    P2PService.instance.myIpv6AddressNotifier.removeListener(_generateQrData);
    super.dispose();
  }

  void _generateQrData() {
    final profile = StorageService.getProfile();
    final myIp = P2PService.instance.myIpv6Address;
    if (profile != null && myIp != null) {
      if (mounted) {
        setState(() {
          _qrData = jsonEncode({
            'publicKey': profile.publicKey,
            'ipAddress': myIp,
          });
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _qrData = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Contact'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Scan this QR Code',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The other person can scan this code\nto add you as a contact.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              if (_qrData != null)
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: QrImageView(
                    data: _qrData!,
                    version: QrVersions.auto,
                    size: 260.0,
                    gapless: false,
                    embeddedImage: const AssetImage('assets/images/logo.png'),
                    embeddedImageStyle: const QrEmbeddedImageStyle(
                      size: Size(40, 40),
                    ),
                  ),
                )
              else
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wifi_rounded, 
                      size: 16, 
                      color: theme.colorScheme.primary
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        P2PService.instance.myIpv6Address ?? 'Discovering IP...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ) ?? const TextStyle(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
