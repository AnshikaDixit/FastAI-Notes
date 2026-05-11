// utils/app_colors.dart
// Curated dark-mode-first color palette for FastAI Notes.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ------------------------------------------------------------------
  // Brand
  // ------------------------------------------------------------------
  static const Color primary = Color(0xFF6C63FF);       // Electric indigo
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color primaryDark = Color(0xFF4A42D6);
  static const Color accent = Color(0xFF00D4B4);        // Teal accent

  // ------------------------------------------------------------------
  // Backgrounds (dark theme)
  // ------------------------------------------------------------------
  static const Color bgDark = Color(0xFF0D0D1A);        // Deep navy-black
  static const Color bgCard = Color(0xFF1A1A2E);        // Slightly lighter card bg
  static const Color bgSurface = Color(0xFF16213E);     // Surface variant

  // ------------------------------------------------------------------
  // Text
  // ------------------------------------------------------------------
  static const Color textPrimary = Color(0xFFF0F0FF);   // Near white with blue tint
  static const Color textSecondary = Color(0xFF8B8BAD); // Muted purple-grey
  static const Color textHint = Color(0xFF5A5A7A);

  // ------------------------------------------------------------------
  // Borders / Dividers
  // ------------------------------------------------------------------
  static const Color border = Color(0xFF2A2A4A);
  static const Color divider = Color(0xFF1E1E3A);

  // ------------------------------------------------------------------
  // Semantic
  // ------------------------------------------------------------------
  static const Color success = Color(0xFF00C896);
  static const Color warning = Color(0xFFFFB547);
  static const Color error = Color(0xFFFF5F7E);
  static const Color info = Color(0xFF4FC3F7);

  // ------------------------------------------------------------------
  // Personal badge
  // ------------------------------------------------------------------
  static const Color personalBadge = Color(0xFFFFB547);

  // ------------------------------------------------------------------
  // Stream screen
  // ------------------------------------------------------------------
  static const Color streamProgress = Color(0xFF6C63FF);
  static const Color streamComplete = Color(0xFF00C896);
  static const Color streamChunk = Color(0xFF1A1A2E);
}
