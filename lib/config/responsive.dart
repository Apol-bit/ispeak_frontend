import 'package:flutter/material.dart';

/// Responsive helper utility for scaling UI elements across all mobile screens.
///
/// This uses a design baseline of 375 x 812 (iPhone X/11/12 standard)
/// and scales proportionally for any screen size.
///
/// Usage:
///   final r = Responsive(context);
///   fontSize: r.sp(16),     // scaled font
///   width: r.w(20),         // scaled horizontal dimension
///   height: r.h(40),        // scaled vertical dimension
///   padding: r.pad(16),     // scaled EdgeInsets.all
///   horizontal: r.padH(20), // scaled EdgeInsets.symmetric(horizontal:)
class Responsive {
  static const double _designWidth = 375.0;
  static const double _designHeight = 812.0;

  final double screenWidth;
  final double screenHeight;
  final double _scaleW;
  final double _scaleH;
  final double _scaleText;

  Responsive(BuildContext context)
      : screenWidth = MediaQuery.of(context).size.width,
        screenHeight = MediaQuery.of(context).size.height,
        _scaleW = MediaQuery.of(context).size.width / _designWidth,
        _scaleH = MediaQuery.of(context).size.height / _designHeight,
        _scaleText = MediaQuery.of(context).size.width / _designWidth;

  /// Scale width-based values (padding, margins, icon sizes, widths)
  double w(double size) => size * _scaleW;

  /// Scale height-based values (vertical spacing, heights)
  double h(double size) => size * _scaleH;

  /// Scale font sizes. Uses width-based scaling with a clamp to prevent
  /// text from becoming too small on narrow devices or too large on tablets.
  double sp(double size) {
    final scaled = size * _scaleText;
    // Clamp between 85% and 120% of original to keep text readable
    return scaled.clamp(size * 0.85, size * 1.2);
  }

  /// Scale icon sizes — uses the smaller of width/height scale
  /// so icons never get too large in one dimension.
  double icon(double size) {
    final scale = _scaleW < _scaleH ? _scaleW : _scaleH;
    return (size * scale).clamp(size * 0.8, size * 1.3);
  }

  /// Scaled EdgeInsets.all
  EdgeInsets pad(double all) => EdgeInsets.all(w(all));

  /// Scaled EdgeInsets.symmetric(horizontal:)
  EdgeInsets padH(double horizontal) =>
      EdgeInsets.symmetric(horizontal: w(horizontal));

  /// Scaled EdgeInsets.symmetric(vertical:)
  EdgeInsets padV(double vertical) =>
      EdgeInsets.symmetric(vertical: h(vertical));

  /// Scaled EdgeInsets.symmetric(horizontal:, vertical:)
  EdgeInsets padHV(double horizontal, double vertical) =>
      EdgeInsets.symmetric(horizontal: w(horizontal), vertical: h(vertical));

  /// Scaled EdgeInsets.fromLTRB
  EdgeInsets padLTRB(double l, double t, double r, double b) =>
      EdgeInsets.fromLTRB(w(l), h(t), w(r), h(b));

  /// Scaled EdgeInsets.only
  EdgeInsets padOnly({double left = 0, double top = 0, double right = 0, double bottom = 0}) =>
      EdgeInsets.only(left: w(left), top: h(top), right: w(right), bottom: h(bottom));

  /// Scaled border radius
  BorderRadius radius(double r) => BorderRadius.circular(w(r));

  /// Whether this is a small phone (width < 360, e.g. iPhone SE, Galaxy A01)
  bool get isSmallPhone => screenWidth < 360;

  /// Whether this is a large phone (width > 414, e.g. iPhone Pro Max, Galaxy Ultra)
  bool get isLargePhone => screenWidth > 414;

  /// Provides a value based on screen size category
  T responsive<T>({required T small, required T medium, T? large}) {
    if (isSmallPhone) return small;
    if (isLargePhone) return large ?? medium;
    return medium;
  }
}
