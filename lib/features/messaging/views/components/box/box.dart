import 'dart:typed_data';

import 'package:bonfire/features/guild/repositories/member.dart';
import 'package:bonfire/features/messaging/controllers/message.dart';
import 'package:bonfire/features/messaging/repositories/name.dart';
import 'package:bonfire/features/messaging/repositories/role_icon.dart';
import 'package:bonfire/features/messaging/views/components/box/avatar.dart';
import 'package:bonfire/features/messaging/views/components/box/content/attachment/attachment.dart';
import 'package:bonfire/features/messaging/views/components/box/content/embed/embed.dart';
import 'package:bonfire/features/messaging/views/components/box/markdown_box.dart';
import 'package:bonfire/features/messaging/views/components/box/mobile_message_drawer.dart';
import 'package:bonfire/features/messaging/views/components/box/popout.dart';
import 'package:bonfire/features/messaging/views/components/box/reply/message_reply.dart';
import 'package:bonfire/shared/utils/platform.dart';
import 'package:bonfire/theme/theme.dart';
import 'package:firebridge/firebridge.dart' hide ButtonStyle;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MessageBox extends ConsumerStatefulWidget {
  final Snowflake messageId;
  final bool showSenderInfo;
  final Snowflake guildId;
  final Channel channel;
  const MessageBox({
    required this.guildId,
    required this.channel,
    super.key,
    required this.messageId,
    required this.showSenderInfo,
  });

  @override
  ConsumerState<MessageBox> createState() => _MessageBoxState();
}

class _MessageBoxState extends ConsumerState<MessageBox>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  String dateTimeFormat(DateTime time) {
    String section1;
    String section2;

    if (time.day == DateTime.now().day) {
      section1 = 'Today';
    } else if (time.day == DateTime.now().day - 1) {
      section1 = 'Yesterday';
    } else {
      section1 = '${time.month}/${time.day}/${time.year}';
    }

    int twelveHour = time.hour % 12;
    twelveHour = twelveHour == 0 ? 12 : twelveHour;
    String section3 = time.hour >= 12 ? 'PM' : 'AM';

    String formattedMinute =
        time.minute < 10 ? '0${time.minute}' : '${time.minute}';
    section2 = ' at $twelveHour:$formattedMinute $section3';

    return section1 + section2;
  }

  bool mentionsSelf(Message message) {
    var selfMember =
        ref.watch(getSelfMemberProvider(widget.guildId)).valueOrNull;
    if (selfMember == null) return false;

    bool directlyMentions =
        message.mentions.any((mention) => mention.id == selfMember.id);

    if (directlyMentions) return true;

    if (message.mentionsEveryone) return true;

    for (var role in message.roleMentionIds) {
      if (selfMember.roleIds.contains(role)) {
        return true;
      }
    }
    return false;
  }

  void _showMobileDrawer() {
    _animationController.forward();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: _animationController,
      builder: (BuildContext context) {
        return GestureDetector(
          onTap: () {},
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return FractionalTranslation(
                translation: Offset(0.0, 1.0 - _animation.value),
                child: child,
              );
            },
            child: DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.2,
              maxChildSize: 0.75,
              builder: (_, controller) {
                return MobileMessageDrawer(messageId: widget.messageId);
              },
            ),
          ),
        );
      },
    ).then((_) {
      print("Drawer dismissed");
      _animationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    Message? message = ref.watch(messageControllerProvider(widget.messageId));

    String? name = ref
            .watch(messageAuthorNameProvider(
                widget.guildId, widget.channel, message!.author))
            .valueOrNull ??
        message.author.username;

    var member = ref
        .watch(getMemberProvider(widget.guildId, message.author.id))
        .valueOrNull;

    var roleIconRef = ref.watch(roleIconProvider(
      widget.guildId,
      message.author.id,
    ));

    Color textColor = ref
            .watch(
              roleColorProvider(
                widget.guildId,
                message.author.id,
              ),
            )
            .valueOrNull ??
        Colors.white;

    Uint8List? roleIcon = roleIconRef.valueOrNull;

    name = member?.nick ?? member?.user?.globalName ?? name;

    bool mentioned = mentionsSelf(message);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Column(
        children: [
          SizedBox(height: widget.showSenderInfo ? 16 : 0),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: mentioned
                  ? Colors.yellow.withOpacity(0.1)
                  : Colors.transparent,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
              // change hover / select color to white
              foregroundColor: Theme.of(context).custom.colorTheme.foreground,
            ),
            onPressed: () {},
            onLongPress: () {
              if (shouldUseMobileLayout(context)) {
                _showMobileDrawer();
              }
            },
            child: Stack(
              children: [
                if (mentioned)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 2,
                        decoration: const BoxDecoration(color: Colors.yellow),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(
                    left: mentioned ? 2 : 0,
                    right: 16,
                  ),
                  child: Column(
                    children: [
                      if (message.referencedMessage != null &&
                          !isSmartwatch(context))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: MessageReply(
                            guildId: widget.guildId,
                            channel: widget.channel,
                            parentMessage: message,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _buildMessageLayout(
                            context, name, textColor, message, roleIcon),
                      ),
                    ],
                  ),
                ),
                if (_isHovering)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: OverlayEntry(
                      maintainState: true,
                      builder: (context) => ContextPopout(
                        messageId: message.id,
                      ),
                    ).builder(context),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageLayout(
    BuildContext context,
    String name,
    Color textColor,
    Message message,
    Uint8List? roleIcon,
  ) {
    bool isWatch = isSmartwatch(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment:
                isWatch ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              if (widget.showSenderInfo)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Avatar(
                    author: message.author,
                    guildId: widget.guildId,
                    channelId: widget.channel.id,
                  ),
                )
              else
                const SizedBox(width: 40),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.referencedMessage != null && isWatch)
                      MessageReply(
                        guildId: widget.guildId,
                        channel: widget.channel,
                        parentMessage: message,
                      ),
                    if (widget.showSenderInfo)
                      _buildMessageHeader(name, textColor, message, roleIcon),
                    if (!isWatch) _buildMessageContent(message),
                  ],
                ),
              ),
            ],
          ),
          if (isWatch)
            Align(
              alignment: Alignment.centerLeft,
              child: _buildMessageContent(message),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageHeader(
    String name,
    Color textColor,
    Message message,
    Uint8List? roleIcon,
  ) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: name,
                style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              const TextSpan(text: '  '),
              TextSpan(
                text: dateTimeFormat(message.timestamp.toLocal()),
                style: const TextStyle(
                  color: Color.fromARGB(189, 255, 255, 255),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (roleIcon != null)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Image.memory(
              roleIcon,
              width: 20,
              height: 20,
            ),
          ),
      ],
    );
  }

  Widget _buildMessageContent(Message message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MessageMarkdownBox(message: message),
        ...message.embeds.map((embed) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: EmbedWidget(
                embed: embed,
              ),
            )),
        ...message.attachments.map((attachment) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AttachmentWidget(
                attachment: attachment,
              ),
            )),
      ],
    );
  }
}
