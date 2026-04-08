import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../providers/app_services.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../theme/gradient_background.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.consultationId,
    required this.currentUserId,
    required this.currentUserName,
    required this.otherUserName,
  });

  final String consultationId;
  final String currentUserId;
  final String currentUserName;
  final String otherUserName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();

    await context.svc.chat.sendMessage(
      consultationId: widget.consultationId,
      senderId: widget.currentUserId,
      senderName: widget.currentUserName,
      text: text,
    );

    // Scroll to bottom after sending
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        centerTitle: true,
      ),
      body: GradientBackground(
        variant: GradientVariant.primary,
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: context.svc.chat.watchMessages(widget.consultationId),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snap.data!;
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 48,
                              color: isDark ? Colors.white.withOpacity(0.2) : Colors.black12),
                          const SizedBox(height: 12),
                          Text(
                            'No messages yet',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white.withOpacity(0.4) : Colors.black38,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Say hello to start the conversation!',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.white.withOpacity(0.25) : Colors.black26,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Auto-scroll to bottom when new messages arrive
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollCtrl.hasClients) {
                      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                    }
                  });

                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      final isMe = msg.senderId == widget.currentUserId;
                      return _MessageBubble(
                        message: msg,
                        isMe: isMe,
                        isDark: isDark,
                      );
                    },
                  );
                },
              ),
            ),

            // Input bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withOpacity(0.4)
                    : Colors.white.withOpacity(0.8),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 4,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accent,
                      ),
                      child: IconButton(
                        onPressed: _send,
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isDark,
  });

  final ChatMessage message;
  final bool isMe;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.accentSecondary.withOpacity(0.2),
              child: Text(
                message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentSecondary),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.accent.withOpacity(0.2)
                    : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      message.senderName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.accentSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                  if (message.timestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DateFormat.Hm().format(message.timestamp!),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark ? Colors.white.withOpacity(0.3) : Colors.black26,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    ).animate().fadeIn(duration: 150.ms);
  }
}
