import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/common.dart';

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'ahora';
  if (d.inHours < 1) return 'hace ${d.inMinutes} min';
  if (d.inDays < 1) return 'hace ${d.inHours} h';
  return DateFormat.MMMd('es').format(t);
}

/// Mensajes y avisos de la persona con la sesión abierta.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mensajes'),
          bottom: TabBar(
            onTap: (i) {
              if (i == 1) state.markNotificationsRead();
            },
            tabs: [
              Tab(
                child: Badge(
                  isLabelVisible: state.unreadMessages > 0,
                  label: Text('${state.unreadMessages}'),
                  child: const Text('Chats'),
                ),
              ),
              Tab(
                child: Badge(
                  isLabelVisible: state.unreadNotifications > 0,
                  label: Text('${state.unreadNotifications}'),
                  child: const Text('Avisos'),
                ),
              ),
            ],
          ),
        ),
        body: const TabBarView(children: [_ChatList(), _NotificationList()]),
      ),
    );
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final chats = state.myConversations
        .where((c) => c.messages.isNotEmpty)
        .toList();
    if (chats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            state.isArtist ? 'Aquí verás los mensajes de tus clientes.' : 'Escríbele a un artista desde su página o desde tus reservas.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = chats[i];
        final unread = state.isArtist ? c.unreadByArtist : c.unreadByClient;
        final last = c.messages.last;
        return ListTile(
          leading: state.isArtist
              ? CircleAvatar(child: Icon(c.clientType.icon))
              : ArtistAvatar(artist: c.artist, size: 40),
          title: Text(state.isArtist ? c.clientName : c.artist.name),
          subtitle: Text(
            '${last.fromArtist == state.isArtist ? 'Tú: ' : ''}${last.text}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_ago(last.sentAt), style: const TextStyle(fontSize: 12)),
              if (unread > 0) Badge(label: Text('$unread')),
            ],
          ),
          onTap: () => openChat(context, c),
        );
      },
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final list = state.myNotifications;
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Aquí aparecen los avisos que llegan a tu teléfono y a tu email.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final n = list[i];
        return Card(
          child: InkWell(
            onTap: n.conversation == null
                ? null
                : () => openChat(context, n.conversation!),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        _ago(n.sentAt),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(n.body),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      const Chip(
                        avatar: Icon(Icons.phone_iphone, size: 16),
                        label: Text('Notificación al teléfono'),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (n.byEmail)
                        Chip(
                          avatar: const Icon(Icons.email, size: 16),
                          label: Text('Email a ${n.recipientEmail}'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Abre el chat entre el cliente con sesión abierta y [artist].
void chatWithArtist(BuildContext context, Artist artist) {
  final state = AppScope.of(context);
  final me = state.account!;
  openChat(
    context,
    state.conversationWith(
      artist: artist,
      clientEmail: me.email,
      clientName: me.displayName,
      clientType: me.clientType,
    ),
  );
}

/// Abre el chat con el cliente de una reserva (vista del artista).
void chatWithClient(BuildContext context, Booking b) {
  openChat(
    context,
    AppScope.of(context).conversationWith(
      artist: b.artist,
      clientEmail: b.clientEmail,
      clientName: b.clientName,
      clientType: b.clientType,
    ),
  );
}

void openChat(BuildContext context, Conversation c) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversation});

  final Conversation conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(AppState state) {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    state.sendMessage(widget.conversation, t);
    _text.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = widget.conversation;
    final iAmArtist = state.isArtist;
    final scheme = Theme.of(context).colorScheme;
    final timeFmt = DateFormat.jm('es');
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => state.markConversationRead(c),
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            if (iAmArtist)
              CircleAvatar(radius: 18, child: Icon(c.clientType.icon, size: 18))
            else
              ArtistAvatar(artist: c.artist, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    iAmArtist ? c.clientName : c.artist.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    iAmArtist ? c.clientType.label : c.artist.category.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: c.messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        iAmArtist
                            ? 'Escríbele a ${c.clientName}.'
                            : 'Pregúntale a ${c.artist.name} por su '
                                  'disponibilidad, repertorio o lo que necesites.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: c.messages.length,
                    itemBuilder: (context, i) {
                      final m = c.messages[i];
                      final mine = m.fromArtist == iAmArtist;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 300),
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                          decoration: BoxDecoration(
                            color: mine
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(m.text),
                              const SizedBox(height: 2),
                              Text(
                                timeFmt.format(m.sentAt),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(state),
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: 'Enviar',
                    icon: const Icon(Icons.send),
                    onPressed: () => _send(state),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
