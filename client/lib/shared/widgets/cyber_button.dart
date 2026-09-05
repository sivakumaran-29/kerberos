import 'package:flutter/material.dart';
import '../theme/cyber_theme.dart';

enum CyberButtonVariant {
  primary,
  emerald,
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

  const CyberButton({
    super.key,
    required this.child,
    this.onTap,
    this.variant = CyberButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 46,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.isExpanded = false,
  });

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    Color glowColor;
    Color textColor;

    switch (widget.variant) {
      case CyberButtonVariant.primary:
        bgColor = _isHovered ? const Color(0xFF0891B2) : CyberTheme.cyan;
        borderColor = CyberTheme.cyanGlow;
        glowColor = CyberTheme.cyan;
        textColor = const Color(0xFF04131D);
        break;
      case CyberButtonVariant.emerald:
        bgColor = _isHovered ? const Color(0xFF059669) : CyberTheme.emerald;
        borderColor = CyberTheme.emeraldGlow;
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
        borderColor = _isHovered ? CyberTheme.cyanGlow : CyberTheme.borderBright;
        glowColor = CyberTheme.cyan;
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: _isHovered && widget.onTap != null
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.35),
                  blurRadius: 16,
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
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
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
