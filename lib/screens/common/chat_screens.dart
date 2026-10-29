import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/social.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import 'report_screen.dart';
import 'reviews.dart';
import 'user_profile_screen.dart';

/// Opens (creating if needed) the chat with another user.
Future<void> openChatWith(
  BuildContext context, {
  required String otherId,
  required String otherName,
  required String otherRole,
  String roomId = '',
  String roomTitle = '',
}) async {
  final me = context.read<SessionProvider>().appUser;
  if (me == null || otherId.isEmpty) return;
  if (otherId == me.uid) {
    showSnack(context, 'This is your own listing.');
    return;
  }
  try {
    final id = await FirestoreService.instance.openConversation(
      me: me,
      otherId: otherId,
      otherName: otherName,
      otherRole: otherRole,
      roomId: roomId,
      roomTitle: roomTitle,
    );
    if (!context.mounted) return;
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(conversationId: id)));
  } catch (e) {
    if (context.mounted) showSnack(context, friendlyError(e), error: true);
  }
}

class ConversationsScreen extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final List<Widget> actions;

  const ConversationsScreen({
    super.key,
    this.title = 'Chats',
    this.emptyMessage =
        'Contact a landlord from a room page or message a roommate match to start chatting.',
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final me = context.watch<SessionProvider>().appUser;
    if (me == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: StreamBuilder<List<Conversation>>(
        stream: FirestoreService.instance.conversationsStream(me.uid),
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(snap.error!);
          if (!snap.hasData) return const SkeletonList(height: 72);
          final list = snap.data!;
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.forum_outlined,
              title: 'No conversations yet',
              message: emptyMessage,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                const Divider(indent: 76, endIndent: 16),
            itemBuilder: (_, i) {
              final c = list[i];
              final unread = c.unreadFor(me.uid);
              final role = c.otherRole(me.uid);
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: AppAvatar(name: c.otherName(me.uid), radius: 24),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(c.otherName(me.uid),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight:
                                  unread > 0 ? FontWeight.w700 : FontWeight.w600)),
                    ),
                    if (role.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Pill(capitalize(role),
                          color: role == 'landlord'
                              ? AppColors.indigo
                              : AppColors.primary),
                    ],
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.roomTitle.isNotEmpty)
                      Text(c.roomTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.indigo)),
                    Text(
                      c.lastMessage.isEmpty
                          ? 'Say hello 👋'
                          : '${c.lastSenderId == me.uid ? 'You: ' : ''}${c.lastMessage}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: unread > 0 ? AppColors.text : AppColors.muted),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(timeAgo(c.lastMessageAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                    const SizedBox(height: 6),
                    if (unread > 0)
                      const CircleAvatar(
                          radius: 5, backgroundColor: AppColors.primary),
                  ],
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatScreen(conversationId: c.id))),
              );
            },
          );
        },
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _fs = FirestoreService.instance;
  int _lastCount = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final uid = context.read<SessionProvider>().appUser?.uid;
    if (uid != null) _fs.markConversationRead(widget.conversationId, uid);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(Conversation c) async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final me = context.read<SessionProvider>().appUser!;
    setState(() => _sending = true);
    _input.clear();
    try {
      await _fs.sendMessage(conversation: c, me: me, text: text);
    } catch (e) {
      _input.text = text;
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<SessionProvider>().appUser;
    if (me == null) return const Scaffold();
    return StreamBuilder<Conversation?>(
      stream: _fs.conversationStream(widget.conversationId),
      builder: (context, cSnap) {
        final c = cSnap.data;
        if (c == null) {
          return Scaffold(
            appBar: AppBar(),
            body: cSnap.hasError
                ? ErrorView(cSnap.error!)
                : const LoadingView(),
          );
        }
        final otherId = c.otherId(me.uid);
        final otherName = c.otherName(me.uid);
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: InkWell(
              onTap: () => UserProfileScreen.open(context, otherId),
              child: Row(
                children: [
                  AppAvatar(name: otherName, radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(otherName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        if (c.roomTitle.isNotEmpty)
                          Text(c.roomTitle,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w400)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'profile':
                      UserProfileScreen.open(context, otherId);
                    case 'review':
                      startReview(context,
                          targetId: otherId, targetName: otherName);
                    case 'report':
                      ReportScreen.open(context,
                          targetType: 'conversation',
                          targetId: c.id,
                          targetName: 'Chat with $otherName',
                          reportedUserId: otherId);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'profile',
                      child: ListTile(
                          leading: Icon(Icons.person_outline),
                          title: Text('View profile'))),
                  PopupMenuItem(
                      value: 'review',
                      child: ListTile(
                          leading: Icon(Icons.rate_review_outlined),
                          title: Text('Write a review'))),
                  PopupMenuItem(
                      value: 'report',
                      child: ListTile(
                          leading: Icon(Icons.flag_outlined,
                              color: AppColors.danger),
                          title: Text('Report conversation'))),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                color: AppColors.warning.withValues(alpha: 0.1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Text(
                  '🔒 Stay safe: never pay deposits outside StudentNest.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _fs.messagesStream(c.id),
                  builder: (context, mSnap) {
                    if (mSnap.hasError) return ErrorView(mSnap.error!);
                    if (!mSnap.hasData) return const LoadingView();
                    final msgs = mSnap.data!;
                    if (msgs.length != _lastCount) {
                      _lastCount = msgs.length;
                      _scrollToBottom();
                      if (c.unreadFor(me.uid) > 0) {
                        _fs.markConversationRead(c.id, me.uid);
                      }
                    }
                    if (msgs.isEmpty) {
                      return EmptyState(
                        icon: Icons.waving_hand_rounded,
                        title: 'Start the conversation',
                        message: 'Say hello to $otherName.',
                      );
                    }
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i];
                        final mine = m.senderId == me.uid;
                        final prev = i > 0 ? msgs[i - 1] : null;
                        final showDay = prev == null ||
                            !_sameDay(prev.createdAt, m.createdAt);
                        return Column(
                          children: [
                            if (showDay)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Text(formatDate(m.createdAt ?? DateTime.now()),
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.muted)),
                              ),
                            _Bubble(message: m, mine: mine),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(c),
                          decoration: InputDecoration(
                            hintText: 'Type a message…',
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        onPressed: () => _send(c),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static bool _sameDay(DateTime? a, DateTime? b) {
    final x = a ?? DateTime.now();
    final y = b ?? DateTime.now();
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  const _Bubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : AppColors.surface,
            border: mine ? null : Border.all(color: AppColors.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(message.text,
                  style: TextStyle(
                      color: mine ? Colors.white : AppColors.text,
                      fontSize: 14.5)),
              const SizedBox(height: 3),
              Text(
                message.createdAt == null
                    ? 'sending…'
                    : formatDateTime(message.createdAt).split(', ').last,
                style: TextStyle(
                    fontSize: 10.5,
                    color: mine ? Colors.white70 : AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
