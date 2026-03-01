import 'package:flutter/material.dart';
import 'package:anis_crm/theme.dart';
import 'package:anis_crm/models/chat_models.dart';
import 'package:anis_crm/services/team_chat_service.dart';
import 'package:anis_crm/services/auth_service.dart';

class TeamChatPage extends StatefulWidget {
  const TeamChatPage({super.key});
  @override
  State<TeamChatPage> createState() => _TeamChatPageState();
}

class _TeamChatPageState extends State<TeamChatPage> {
  bool _loadingChannels = true;
  String? _activeChannelId;
  bool _showSidebar = true; // for mobile toggle

  @override
  void initState() {
    super.initState();
    TeamChatService.instance.addListener(_onUpdate);
    _loadChannels();
  }

  @override
  void dispose() {
    TeamChatService.instance.removeListener(_onUpdate);
    TeamChatService.instance.stopPolling();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadChannels() async {
    setState(() => _loadingChannels = true);
    await TeamChatService.instance.loadChannels();
    if (mounted) setState(() => _loadingChannels = false);
  }

  void _selectChannel(String channelId) {
    setState(() {
      _activeChannelId = channelId;
      _showSidebar = false; // auto-hide sidebar on mobile after selection
    });
    TeamChatService.instance.setActiveChannel(channelId);
  }

  void _showNewDmDialog() async {
    final me = AuthService.instance.user;
    if (me == null) return;

    List<CrmUser> users = [];
    try {
      users = await AuthService.instance.listUsers();
      users.removeWhere((u) => u.id == me.id);
    } catch (_) {}

    if (!mounted || users.isEmpty) return;

    final selected = await showDialog<CrmUser>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 400),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Start Conversation', style: tt.titleMedium?.semiBold),
                const SizedBox(height: 4),
                Text('Select a team member',
                    style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.45))),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: users.length,
                    itemBuilder: (_, i) {
                      final u = users[i];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: cs.primary.withValues(alpha: 0.1),
                          child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                              style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.primary)),
                        ),
                        title: Text(u.name, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                        subtitle: Text(u.email, style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.45))),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onTap: () => Navigator.pop(ctx, u),
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      final ch = await TeamChatService.instance.getOrCreateDM(
        selected.id, selected.name, me.id, me.name,
      );
      if (ch != null) _selectChannel(ch.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dk = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;
    final wide = MediaQuery.of(context).size.width >= 760;
    final me = AuthService.instance.user;

    // On mobile, show sidebar OR chat, not both
    if (!wide) {
      if (_showSidebar || _activeChannelId == null) {
        return _buildSidebar(cs, dk, tt, me, isMobile: true);
      }
      return Column(children: [
        // Mobile back bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.08))),
          ),
          child: Row(children: [
            IconButton(
              onPressed: () => setState(() => _showSidebar = true),
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to channels',
            ),
            Text(_getChannelName(me?.id ?? ''), style: tt.titleSmall?.semiBold),
          ]),
        ),
        Expanded(child: _ChatView(channelId: _activeChannelId!, myId: me?.id ?? '', cs: cs, dk: dk)),
      ]);
    }

    // Desktop: side-by-side
    return Row(children: [
      _buildSidebar(cs, dk, tt, me, isMobile: false),
      Expanded(
        child: _activeChannelId == null
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.forum_outlined, size: 32, color: cs.onSurface.withValues(alpha: 0.15)),
                  ),
                  const SizedBox(height: 16),
                  Text('Select a conversation', style: tt.titleMedium?.semiBold),
                  const SizedBox(height: 6),
                  Text('Or start a new one with a team member',
                      style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.4))),
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
                    onPressed: _showNewDmDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Conversation'),
                  ),
                ]),
              )
            : _ChatView(channelId: _activeChannelId!, myId: me?.id ?? '', cs: cs, dk: dk),
      ),
    ]);
  }

  String _getChannelName(String myId) {
    final ch = TeamChatService.instance.channels.where((c) => c.id == _activeChannelId).firstOrNull;
    return ch?.displayName(myId) ?? 'Chat';
  }

  Widget _buildSidebar(ColorScheme cs, bool dk, TextTheme tt, CrmUser? me, {required bool isMobile}) {
    return Container(
      width: isMobile ? double.infinity : 280,
      decoration: BoxDecoration(
        color: dk ? cs.surface.withValues(alpha: 0.4) : cs.surface.withValues(alpha: 0.6),
        border: isMobile ? null : Border(right: BorderSide(color: cs.outline.withValues(alpha: 0.08))),
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
          child: Row(children: [
            Icon(Icons.chat_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 10),
            Text('Messages', style: tt.titleMedium?.semiBold),
            const Spacer(),
            IconButton(
              onPressed: _showNewDmDialog,
              icon: Icon(Icons.edit_square, size: 20, color: cs.primary),
              tooltip: 'New conversation',
            ),
          ]),
        ),
        Divider(height: 1, color: cs.outline.withValues(alpha: 0.06)),
        // Channel list
        Expanded(
          child: _loadingChannels
              ? Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)))
              : TeamChatService.instance.channels.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.chat_bubble_outline, size: 36, color: cs.onSurface.withValues(alpha: 0.15)),
                          const SizedBox(height: 12),
                          Text('No conversations yet', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text('Tap + to start one', style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.4))),
                        ]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: TeamChatService.instance.channels.length,
                      itemBuilder: (_, i) {
                        final ch = TeamChatService.instance.channels[i];
                        final active = ch.id == _activeChannelId;
                        return _ChannelTile(
                          channel: ch,
                          active: active,
                          myId: me?.id ?? '',
                          cs: cs,
                          dk: dk,
                          onTap: () => _selectChannel(ch.id),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHANNEL TILE
// ═══════════════════════════════════════════════════════════════════════════════

class _ChannelTile extends StatelessWidget {
  final ChatChannel channel;
  final bool active;
  final String myId;
  final ColorScheme cs;
  final bool dk;
  final VoidCallback onTap;
  const _ChannelTile({required this.channel, required this.active, required this.myId,
      required this.cs, required this.dk, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = channel.displayName(myId);
    final isGeneral = channel.type == 'general';
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: active ? cs.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isGeneral
                ? cs.tertiary.withValues(alpha: 0.12)
                : cs.primary.withValues(alpha: 0.1),
            child: Icon(
              isGeneral ? Icons.groups_outlined : Icons.person_outlined,
              size: 18,
              color: isGeneral ? cs.tertiary : cs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (channel.lastMessage.isNotEmpty)
                Text(
                  '${channel.lastMessageBy.isNotEmpty ? "${channel.lastMessageBy}: " : ""}${channel.lastMessage}',
                  style: tt.bodySmall?.withColor(cs.onSurface.withValues(alpha: 0.4)),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT VIEW
// ═══════════════════════════════════════════════════════════════════════════════

class _ChatView extends StatefulWidget {
  final String channelId;
  final String myId;
  final ColorScheme cs;
  final bool dk;
  const _ChatView({required this.channelId, required this.myId, required this.cs, required this.dk});

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    setState(() => _sending = true);
    await TeamChatService.instance.sendMessage(widget.channelId, text);
    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final dk = widget.dk;
    final messages = TeamChatService.instance.messagesFor(widget.channelId);
    final tt = Theme.of(context).textTheme;

    _scrollToBottom();

    return Column(children: [
      // Messages area
      Expanded(
        child: messages.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chat_bubble_outline, size: 40, color: cs.onSurface.withValues(alpha: 0.12)),
                  const SizedBox(height: 12),
                  Text('No messages yet. Say hello!',
                      style: tt.bodyMedium?.withColor(cs.onSurface.withValues(alpha: 0.4))),
                ]),
              )
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(18),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i];
                  final isMe = msg.isMe(widget.myId);
                  final showAvatar = i == 0 || messages[i - 1].senderId != msg.senderId;

                  return Padding(
                    padding: EdgeInsets.only(
                      top: showAvatar ? 12 : 2,
                      left: isMe ? 60 : 0,
                      right: isMe ? 0 : 60,
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (showAvatar && !isMe)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4, left: 4),
                            child: Text(msg.senderName,
                                style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w600,
                                    color: cs.primary.withValues(alpha: 0.7))),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe
                                ? cs.primary.withValues(alpha: 0.12)
                                : dk ? cs.surface.withValues(alpha: 0.6) : cs.surfaceContainerLow,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(14),
                              topRight: const Radius.circular(14),
                              bottomLeft: Radius.circular(isMe ? 14 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 14),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(msg.text, style: tt.bodyMedium?.copyWith(height: 1.4)),
                              const SizedBox(height: 4),
                              Text(
                                '${msg.ts.hour.toString().padLeft(2, '0')}:${msg.ts.minute.toString().padLeft(2, '0')}',
                                style: tt.labelSmall?.withColor(cs.onSurface.withValues(alpha: 0.3)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      // Input bar
      Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 10, 14),
        decoration: BoxDecoration(
          color: dk ? cs.surface.withValues(alpha: 0.5) : cs.surface,
          border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.06))),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              style: tt.bodyMedium,
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: tt.bodyMedium?.withColor(cs.onSurface.withValues(alpha: 0.3)),
                filled: true,
                fillColor: dk ? cs.surface.withValues(alpha: 0.3) : cs.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.send_rounded, color: cs.primary, size: 22),
            tooltip: 'Send',
          ),
        ]),
      ),
    ]);
  }
}
