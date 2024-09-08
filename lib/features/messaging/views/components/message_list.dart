import 'dart:async';

import 'package:bonfire/features/channels/controllers/channel.dart';
import 'package:bonfire/features/guild/controllers/guild.dart';
import 'package:bonfire/features/messaging/repositories/messages.dart';
import 'package:bonfire/features/messaging/views/components/bar.dart';
import 'package:bonfire/features/messaging/views/components/box/box.dart';
import 'package:bonfire/features/messaging/views/components/box/channel_header.dart';
import 'package:bonfire/features/messaging/views/components/box/message_loading_animation.dart';
import 'package:bonfire/features/messaging/views/components/keyboard_buffer.dart';
import 'package:bonfire/shared/utils/channel_name.dart';
import 'package:bonfire/theme/theme.dart';
import 'package:firebridge/firebridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bonfire/shared/utils/platform.dart';

class MessageList extends ConsumerStatefulWidget {
  final Snowflake guildId;
  final Snowflake channelId;
  const MessageList(
      {super.key, required this.guildId, required this.channelId});

  @override
  ConsumerState<MessageList> createState() => _MessageViewState();
}

class _MessageViewState extends ConsumerState<MessageList>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  List<Message> loadedMessages = [];
  Message? lastScrollMessage;
  Message? firstBatchLastMessage;
  Logger logger = Logger("MessageView");
  bool _isLoadingMore = false;
  bool sentInitialAck = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 0),
      // reverseDuration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == 0) {
      loadedMessages.first.manager.acknowledge(loadedMessages.first.id);
    }
    if (!_isLoadingMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 5000) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (firstBatchLastMessage == null) return;
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    lastScrollMessage = lastScrollMessage ?? firstBatchLastMessage!;
    List<Message>? recents = await ref
        .read(messagesProvider(widget.channelId).notifier)
        .fetchMessages(before: lastScrollMessage!, limit: 50);

    if (recents.isNotEmpty) {
      if (lastScrollMessage?.id != recents.last.id) {
        setState(() {
          lastScrollMessage = recents.last;
        });
      }
    }
    _isLoadingMore = false;
  }

  Widget _buildMessageList() {
    return ListView.custom(
      controller: _scrollController,
      reverse: true,
      shrinkWrap: true,
      padding: EdgeInsets.only(
        bottom: 12,
        top: isSmartwatch(context)
            ? 0
            : 50, // add the height of the channel header
        left: 0,
        right: 0,
      ),
      childrenDelegate: SliverChildBuilderDelegate(
        childCount: loadedMessages.length + (isSmartwatch(context) ? 1 : 0),
        findChildIndexCallback: (Key key) {
          final ValueKey<BigInt> valueKey = key as ValueKey<BigInt>;
          var idx = loadedMessages
              .indexWhere((message) => message.id.value == valueKey.value);
          if (idx == -1) return null;
          return idx;
        },
        (context, index) {
          if (isSmartwatch(context) && index == 0) {
            return MessageBar(
              guildId: ref
                      .read(guildControllerProvider(widget.guildId))
                      .valueOrNull
                      ?.id ??
                  Snowflake.zero,
              channel: ref
                  .read(channelControllerProvider(widget.channelId))
                  .valueOrNull!,
            );
          }

          final messageIndex = isSmartwatch(context) ? index - 1 : index;
          bool showAuthor = true;

          if (messageIndex + 1 < loadedMessages.length) {
            Message currentMessage = loadedMessages[messageIndex];
            Message lastMessage = loadedMessages[messageIndex + 1];

            showAuthor = lastMessage.author.id != currentMessage.author.id;

            if (currentMessage.timestamp
                    .difference(lastMessage.timestamp)
                    .inMinutes >
                5) {
              showAuthor = true;
            }
            if (currentMessage.referencedMessage != null) {
              showAuthor = true;
            }
          } else {
            showAuthor = true;
          }
          if (messageIndex == loadedMessages.length - 1 &&
              lastScrollMessage == null) {
            firstBatchLastMessage = loadedMessages[messageIndex];
          }

          return MessageBox(
            key: ValueKey(loadedMessages[messageIndex].id.value),
            guildId: ref
                    .read(guildControllerProvider(widget.guildId))
                    .valueOrNull
                    ?.id ??
                Snowflake.zero,
            channel: ref
                .read(channelControllerProvider(widget.channelId))
                .valueOrNull!,
            messageId: loadedMessages[messageIndex].id,
            showSenderInfo: showAuthor,
          );
        },
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      itemCount: 10, // Show 10 loading placeholders
      itemBuilder: (context, index) => const MessageLoadingAnimation(),
    );
  }

  @override
  Widget build(BuildContext context) {
    var messageOutput = ref.watch(messagesProvider(widget.channelId));

    Widget content = Container();

    messageOutput.when(
      data: (messages) {
        loadedMessages = messages ?? [];
        _fadeController.forward();
        content = _buildMessageList();
      },
      loading: () {
        loadedMessages = [];
        // we could also reverse it, but that doesn't look as good imo
        _fadeController.reverse();
        content = _buildLoadingList();
      },
      error: (error, stack) {
        logger.severe("Error loading messages", error, stack);
        loadedMessages = [];
        _fadeController.forward();
        content = Center(
          child: Text('Error loading messages: ${error.toString()}'),
        );
      },
    );

    String channelName = "";
    Channel? channel =
        ref.watch(channelControllerProvider(widget.channelId)).valueOrNull;

    Guild? guild =
        ref.watch(guildControllerProvider(widget.guildId)).valueOrNull;

    if (channel == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    channelName = getChannelName(channel);

    return Scaffold(
      body: Container(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  FadeTransition(
                      opacity: _fadeAnimation,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: content,
                      )),
                  if (!isSmartwatch(context))
                    ChannelHeader(channelName: channelName),
                ],
              ),
            ),
            if (!isSmartwatch(context))
              MessageBar(
                guildId: guild?.id ?? Snowflake.zero,
                channel: channel,
              ),
            if (!isSmartwatch(context))
              SizedBox(
                height: MediaQuery.of(context).padding.bottom,
              ),
            if (!isSmartwatch(context)) const KeyboardBuffer()
          ],
        ),
      ),
    );
  }
}
