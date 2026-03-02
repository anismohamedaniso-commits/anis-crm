import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:anis_crm/services/api_client.dart';
import 'package:anis_crm/theme.dart';

/// Global search overlay triggered from the app shell.
class GlobalSearchBar extends StatefulWidget {
  const GlobalSearchBar({super.key});

  @override
  State<GlobalSearchBar> createState() => _GlobalSearchBarState();
}

class _GlobalSearchBarState extends State<GlobalSearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  bool _loading = false;
  List<_SearchResult> _results = [];
  bool _showResults = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && _results.isNotEmpty) {
      _showOverlay();
    } else if (!_focusNode.hasFocus) {
      // Delay to allow tap on result
      Future.delayed(const Duration(milliseconds: 200), _removeOverlay);
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _showResults = false;
      });
      _removeOverlay();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query.trim()));
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.instance.globalSearch(query);
      if (data != null) {
        final parsed = <_SearchResult>[];
        for (final lead in (data['leads'] as List? ?? [])) {
          parsed.add(_SearchResult(
            type: 'lead',
            id: lead['id'] as String? ?? '',
            title: lead['name'] as String? ?? '',
            subtitle: lead['status'] as String? ?? '',
            icon: Icons.person,
          ));
        }
        for (final task in (data['tasks'] as List? ?? [])) {
          parsed.add(_SearchResult(
            type: 'task',
            id: task['id'] as String? ?? '',
            title: task['title'] as String? ?? '',
            subtitle: task['status'] as String? ?? '',
            icon: Icons.task,
          ));
        }
        for (final deal in (data['deals'] as List? ?? [])) {
          parsed.add(_SearchResult(
            type: 'deal',
            id: deal['id'] as String? ?? '',
            title: deal['title'] as String? ?? '',
            subtitle: deal['stage'] as String? ?? '',
            icon: Icons.attach_money,
          ));
        }
        for (final activity in (data['activities'] as List? ?? [])) {
          parsed.add(_SearchResult(
            type: 'activity',
            id: activity['lead_id'] as String? ?? '',
            title: activity['text'] as String? ?? '',
            subtitle: activity['type'] as String? ?? '',
            icon: Icons.timeline,
          ));
        }
        setState(() {
          _results = parsed;
          _showResults = true;
        });
        if (parsed.isNotEmpty) _showOverlay(); else _removeOverlay();
      }
    } catch (e) {
      debugPrint('GlobalSearch error: $e');
    }
    setState(() => _loading = false);
  }

  void _onTapResult(_SearchResult result) {
    _removeOverlay();
    _controller.clear();
    _focusNode.unfocus();
    setState(() => _showResults = false);

    switch (result.type) {
      case 'lead':
      case 'activity':
        context.go('/app/lead/${result.id}');
        break;
      case 'task':
        context.go('/app/tasks');
        break;
      case 'deal':
        context.go('/app/deals');
        break;
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: (ctx) {
      final screenW = MediaQuery.of(context).size.width;
      final overlayW = screenW < 400 ? screenW - 32 : 360.0;
      return Positioned(
        width: overlayW,
        child: CompositedTransformFollower(
          link: _layerLink,
          offset: const Offset(0, 44),
          showWhenUnlinked: false,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (ctx, i) {
                  final r = _results[i];
                  return ListTile(
                    leading: Icon(r.icon, size: 20),
                    title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${r.type.toUpperCase()} · ${r.subtitle}', style: const TextStyle(fontSize: 12)),
                    dense: true,
                    onTap: () => _onTapResult(r),
                  );
                },
              ),
            ),
          ),
        ),
      );
    });
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    return CompositedTransformTarget(
      link: _layerLink,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280, minWidth: 120, maxHeight: 38, minHeight: 38),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search leads, tasks, deals…',
            hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            prefixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                : const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: dk ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            isDense: true,
          ),
        ),
      ),
    );
  }
}

class _SearchResult {
  final String type;
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  const _SearchResult({required this.type, required this.id, required this.title, required this.subtitle, required this.icon});
}
