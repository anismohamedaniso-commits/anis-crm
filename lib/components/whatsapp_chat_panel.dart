import 'package:anis_crm/components/chat_bubble.dart';
import 'package:anis_crm/models/lead.dart';
import 'package:anis_crm/models/message.dart';
import 'package:anis_crm/services/message_service.dart';
import 'package:anis_crm/state/app_state.dart';
import 'package:anis_crm/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Rich WhatsApp chat panel used inside the Lead detail page.
class WhatsAppChatPanel extends StatefulWidget {
  const WhatsAppChatPanel({super.key, required this.lead});
  final LeadModel? lead;

  @override
  State<WhatsAppChatPanel> createState() => _WhatsAppChatPanelState();
}

class _WhatsAppChatPanelState extends State<WhatsAppChatPanel> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    MessageService.instance.loadAll();
    final id = widget.lead?.id;
    if (id != null) {
      MessageService.instance.hydrateFromRemote(id);
      MessageService.instance.subscribeLead(id);
    }
  }

  @override
  void didUpdateWidget(covariant WhatsAppChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lead?.id != widget.lead?.id) {
      final oldId = oldWidget.lead?.id;
      if (oldId != null) MessageService.instance.unsubscribeLead(oldId);
      final id = widget.lead?.id;
      if (id != null) {
        MessageService.instance.hydrateFromRemote(id);
        MessageService.instance.subscribeLead(id);
      }
    }
  }

  @override
  void dispose() {
    final id = widget.lead?.id;
    if (id != null) MessageService.instance.unsubscribeLead(id);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final app = context.watch<AppState>();
    final lead = widget.lead;

    return Card(
      child: SizedBox(
        height: 560,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(children: [
              Icon(Icons.forum_outlined, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text('WhatsApp conversation', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (lead != null)
                Text(lead.name, style: Theme.of(context).textTheme.labelLarge?.withColor(cs.onSurfaceVariant)),
            ]),
          ),
          const Divider(height: 1),

          // Not connected state
          if (!app.whatsAppConnected)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.link_off, color: cs.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text('WhatsApp is not connected', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Connect WhatsApp in Settings to send and receive messages for this lead.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context.go('/app/settings'),
                      icon: const Icon(Icons.settings),
                      label: const Text('Open Settings'),
                    )
                  ]),
                ),
              ),
            )
          else if (lead == null || (lead.phone == null || lead.phone!.isEmpty))
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.contact_phone_outlined, color: cs.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text('No phone number', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Add a valid phone number to this lead to start a WhatsApp chat.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant)),
                  ]),
                ),
              ),
            )
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: ValueListenableBuilder(
                  valueListenable: MessageService.instance.byLead,
                  builder: (context, map, _) {
                    final list = MessageService.instance.listFor(lead.id);
                    if (list.isEmpty) {
                      return Center(
                        child: Text('No messages yet. Say hello to start the conversation.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge?.withColor(cs.onSurfaceVariant)),
                      );
                    }
                    return ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final m = list[i];
                        final isOut = m.direction == MessageDirection.outgoing;
                        final time = _fmtTime(m.createdAt);
                        final statusLabel = switch (m.status) {
                          MessageStatus.sending => 'Sending…',
                          MessageStatus.sent => 'Sent',
                          MessageStatus.delivered => 'Delivered',
                          MessageStatus.failed => 'Failed',
                          MessageStatus.composing => 'Draft',
                        };
                        return Column(
                          crossAxisAlignment: isOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
                              child: ChatBubble(
                                text: m.text,
                                timestamp: '$time · $statusLabel',
                                isOutgoing: isOut,
                              ),
                            ),
                            if (isOut && m.status == MessageStatus.failed)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: TextButton.icon(
                                  icon: const Icon(Icons.refresh, size: 16),
                                  onPressed: () async => _retrySend(m),
                                  label: const Text('Retry', overflow: TextOverflow.ellipsis),
                                  style: TextButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap, padding: const EdgeInsets.symmetric(horizontal: 8)),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),

          const Divider(height: 1),

          // Input bar
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(children: [
              IconButton(onPressed: null, icon: const Icon(Icons.attach_file)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
                  ),
                  onSubmitted: (_) => _sendIfPossible(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: (_sending || _controller.text.trim().isEmpty || !app.whatsAppConnected || lead == null || (lead.phone == null || lead.phone!.isEmpty)) ? null : _sendIfPossible,
                icon: _sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                label: const Text('Send'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _retrySend(MessageModel m) async {
    final lead = widget.lead;
    if (lead == null || lead.phone == null || lead.phone!.isEmpty) return;
    if (_sending) return;
    try {
      setState(() => _sending = true);
      await MessageService.instance.sendWhatsApp(leadId: lead.id, toPhone: lead.phone!, text: m.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message re-sent')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendIfPossible() async {
    final lead = widget.lead;
    if (lead == null || lead.phone == null || lead.phone!.isEmpty) return;
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    try {
      setState(() => _sending = true);
      await MessageService.instance.sendWhatsApp(leadId: lead.id, toPhone: lead.phone!, text: text);
      _controller.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
