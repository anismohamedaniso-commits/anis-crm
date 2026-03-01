import 'package:flutter/material.dart';

/// Wraps a list of children with staggered fade-in + slide-up animations.
/// Use this for dashboard cards, list items, etc.
class StaggeredList extends StatefulWidget {
  const StaggeredList({
    super.key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 60),
    this.animationDuration = const Duration(milliseconds: 400),
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
    this.spacing = 0,
  });

  final List<Widget> children;
  final Duration staggerDelay;
  final Duration animationDuration;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double spacing;

  @override
  State<StaggeredList> createState() => _StaggeredListState();
}

class _StaggeredListState extends State<StaggeredList> with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _fadeAnims = [];
  final List<Animation<Offset>> _slideAnims = [];

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    for (int i = 0; i < widget.children.length; i++) {
      final ctrl = AnimationController(vsync: this, duration: widget.animationDuration);
      _controllers.add(ctrl);
      _fadeAnims.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      _slideAnims.add(Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)));

      // Stagger the start
      Future.delayed(widget.staggerDelay * i, () {
        if (mounted) ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      mainAxisSize: widget.mainAxisSize,
      children: [
        for (int i = 0; i < widget.children.length; i++) ...[
          if (i > 0 && widget.spacing > 0) SizedBox(height: widget.spacing),
          FadeTransition(
            opacity: _fadeAnims[i],
            child: SlideTransition(
              position: _slideAnims[i],
              child: widget.children[i],
            ),
          ),
        ],
      ],
    );
  }
}

/// Animate a single widget with fade-in + slide-up on first build.
class AnimateIn extends StatefulWidget {
  const AnimateIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<AnimateIn> createState() => _AnimateInState();
}

class _AnimateInState extends State<AnimateIn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
