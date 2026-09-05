import 'package:flutter/material.dart';
import '../theme/cyber_theme.dart';

enum CyberButtonVariant {
  whitePill, // Solid white pill with dark text (React Bits primary)
  glassPill, // Dark translucent glass pill with subtle border
  purple,    // Electric purple accent pill (#A855F7)
  primary,
  emerald,
  gradient,
  glass,
  danger,
}

class CyberButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final CyberButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double height;
  final EdgeInsetsGeometry padding;
  final bool isExpanded;
  final double borderRadius;

  const CyberButton({
    super.key,
    required this.child,
    this.onTap,
    this.variant = CyberButtonVariant.whitePill,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 42,
    this.padding = const EdgeInsets.symmetric(horizontal: 22),
    this.isExpanded = false,
    this.borderRadius = 100.0, // Default to rounded-full pill
  });

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    Gradient? bgGradient;
    Color borderColor;
    Color glowColor;
    Color textColor;

    switch (widget.variant) {
      case CyberButtonVariant.whitePill:
        bgColor = _isHovered ? const Color(0xFFF1F5F9) : Colors.white;
        borderColor = Colors.white;
        glowColor = Colors.white;
        textColor = const Color(0xFF120F17);
        break;
      case CyberButtonVariant.glassPill:
        bgColor = _isHovered ? const Color(0x25FFFFFF) : const Color(0x12FFFFFF);
        borderColor = _isHovered ? const Color(0x44FFFFFF) : const Color(0x22FFFFFF);
        glowColor = Colors.white;
        textColor = Colors.white;
        break;
      case CyberButtonVariant.purple:
        bgColor = _isHovered ? const Color(0xFF9333EA) : CyberTheme.accentColor;
        borderColor = const Color(0xFFC084FC);
        glowColor = CyberTheme.accentColor;
        textColor = Colors.white;
        break;
      case CyberButtonVariant.gradient:
        bgGradient = _isHovered
            ? const LinearGradient(
                colors: [Color(0xFF9333EA), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : CyberTheme.shardGradient;
        borderColor = const Color(0x66A855F7);
        glowColor = CyberTheme.accentColor;
        textColor = Colors.white;
        break;
      case CyberButtonVariant.primary:
        bgColor = _isHovered ? const Color(0xFF9333EA) : CyberTheme.accentColor;
        borderColor = const Color(0xFFC084FC);
        glowColor = CyberTheme.accentColor;
        textColor = Colors.white;
        break;
      case CyberButtonVariant.emerald:
        bgColor = _isHovered ? const Color(0xFF059669) : CyberTheme.emerald;
        borderColor = CyberTheme.emeraldLight;
        glowColor = CyberTheme.emerald;
        textColor = const Color(0xFF021B12);
        break;
      case CyberButtonVariant.danger:
        bgColor = _isHovered ? const Color(0xFFE11D48) : CyberTheme.coral;
        borderColor = const Color(0xFFFB7185);
        glowColor = CyberTheme.coral;
        textColor = Colors.white;
        break;
      case CyberButtonVariant.glass:
        bgColor = _isHovered ? CyberTheme.surfaceElevated : CyberTheme.surface;
        borderColor = _isHovered ? CyberTheme.borderBright : CyberTheme.border;
        glowColor = CyberTheme.accentColor;
        textColor = CyberTheme.textPrimary;
        break;
    }

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      width: widget.isExpanded ? double.infinity : widget.width,
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: bgColor,
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: _isHovered && widget.onTap != null
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: widget.variant == CyberButtonVariant.whitePill ? 0.25 : 0.4),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Center(
        child: widget.isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 16, color: textColor),
                    const SizedBox(width: 8),
                  ],
                  DefaultTextStyle(
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                    child: widget.child,
                  ),
                ],
              ),
      ),
    );

    return MouseRegion(
      cursor: widget.onTap != null && !widget.isLoading
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.isLoading ? null : widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: content,
        ),
      ),
    );
  }
}
