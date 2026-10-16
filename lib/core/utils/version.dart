import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/auth_vibe.dart';

/// Small "developer • version" credit line shown at the bottom of the
/// splash and language-selection screens. Pulled out into its own widget
/// so both screens stay in sync without duplicating the same private class
/// in two places (which also can't be imported across files).
class VersionFooter extends StatelessWidget {
  const VersionFooter({
    super.key,
    this.developer = 'isi-group-developer',
    this.version = 'version 1.0.0',
  });

  final String developer;
  final String version;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            developer,
            style: TextStyle(
              color: Vibe.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: Vibe.muted.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Text(
            version,
            style: TextStyle(
              color: Vibe.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
