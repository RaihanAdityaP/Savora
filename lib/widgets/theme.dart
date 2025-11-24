import 'package:flutter/material.dart';

class AppTheme {
  // Primary Colors
  static const Color primaryDark = Color(0xFF264653);
  static const Color primaryTeal = Color(0xFF2A9D8F);
  static const Color primaryYellow = Color(0xFFE9C46A);
  static const Color primaryOrange = Color(0xFFF4A261);
  static const Color primaryCoral = Color(0xFFE76F51);

  // Background Colors
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color cardBackground = Colors.white;

  // Text Colors
  static const Color textPrimary = Color(0xFF264653);
  static const Color textSecondary = Color(0xFF6B7280);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryDark,
      primaryTeal,
      primaryYellow,
      primaryOrange,
      primaryCoral,
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [primaryCoral, primaryOrange],
  );

  static const LinearGradient tealGradient = LinearGradient(
    colors: [primaryTeal, Color(0xFF3DB9A9)],
  );

  static const LinearGradient orangeGradient = LinearGradient(
    colors: [primaryOrange, primaryYellow],
  );

  static LinearGradient get cardGradient => LinearGradient(
        colors: [
          primaryCoral.withValues(alpha: 0.05),
          primaryOrange.withValues(alpha: 0.1),
        ],
      );

  static LinearGradient get inputGradient => LinearGradient(
        colors: [
          primaryCoral.withValues(alpha: 0.05),
          primaryOrange.withValues(alpha: 0.08),
        ],
      );

  // Admin/Premium Gradients
  static const LinearGradient adminGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
  );

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF9F8FFF)],
  );

  // Box Shadows
  static List<BoxShadow> get primaryShadow => [
        BoxShadow(
          color: primaryCoral.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primaryCoral.withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: primaryCoral.withValues(alpha: 0.4),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ];

  // Border Decorations
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryCoral.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: cardShadow,
      );

  static BoxDecoration inputDecoration(Color iconColor) => BoxDecoration(
        gradient: LinearGradient(
          colors: [
            iconColor.withValues(alpha: 0.05),
            iconColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      );

  // Button Styles
  static BoxDecoration get primaryButtonDecoration => BoxDecoration(
        gradient: accentGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: buttonShadow,
      );

  static BoxDecoration get outlinedButtonDecoration => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      );

  // Section Header Style
  static Widget buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [primaryCoral, primaryOrange],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: accentGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  // Text Styles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: textPrimary,
  );

  static TextStyle bodySmall = TextStyle(
    fontSize: 13,
    color: Colors.grey.shade600,
  );

  static const TextStyle buttonText = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  // Input Decoration
  static InputDecoration buildInputDecoration({
    required String hint,
    required IconData icon,
    Color? iconColor,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Padding(
        padding: EdgeInsets.only(top: maxLines > 1 ? 12 : 0),
        child: Icon(icon, color: iconColor ?? Colors.grey.shade600, size: 20),
      ),
      suffixIcon: suffixIcon,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  // Role-based colors
  static List<Color> getRoleGradient(String role) {
    switch (role) {
      case 'admin':
        return [const Color(0xFFFFD700), const Color(0xFFFFA500)];
      case 'premium':
        return [const Color(0xFF6C63FF), const Color(0xFF9F8FFF)];
      default:
        return [Colors.grey.shade400, Colors.grey.shade500];
    }
  }

  static String getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'ADMIN';
      case 'premium':
        return 'PREMIUM';
      default:
        return 'USER';
    }
  }

  // Tag Chip Decoration
  static BoxDecoration get selectedTagDecoration => BoxDecoration(
        gradient: accentGradient,
        borderRadius: BorderRadius.circular(20),
      );

  static BoxDecoration get unselectedTagDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      );

  // Empty State Widget
  static Widget buildEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade100, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Info Banner
  static Widget buildInfoBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryCoral.withValues(alpha: 0.1),
            primaryOrange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryCoral.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: primaryCoral, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: primaryCoral.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}