import 'package:bonfire/features/me/views/components/messages.dart';
import 'package:bonfire/features/members/views/member_list.dart';
import 'package:bonfire/features/messaging/views/messages.dart';
import 'package:bonfire/features/overview/controllers/navigation_bar.dart';
import 'package:bonfire/features/overview/views/overlapping_panels.dart';
import 'package:bonfire/features/overview/views/sidebar.dart';
import 'package:firebridge/firebridge.dart' hide Builder;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_platform/universal_platform.dart';

class MessageOverview extends ConsumerStatefulWidget {
  final Snowflake? channelId;
  const MessageOverview({super.key, this.channelId});

  @override
  ConsumerState<MessageOverview> createState() => _MessageOverviewState();
}

class _MessageOverviewState extends ConsumerState<MessageOverview> {
  RevealSide selfPanelState = RevealSide.main;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) {
          if (UniversalPlatform.isDesktop) {
            return Row(
              children: [
                const Sidebar(guildId: Snowflake.zero),
                const SizedBox(
                  width: 300,
                  child: Expanded(
                    child: PrivateMessages(),
                  ),
                ),
                (widget.channelId != null)
                    ? Expanded(
                        child: MessageView(
                          guildId: Snowflake.zero,
                          channelId: widget.channelId!,
                        ),
                      )
                    : const SizedBox()
              ],
            );
          } else {
            return OverlappingPanels(
              onSideChange: (value) {
                FocusScope.of(context).unfocus();
                selfPanelState = value;
                ref.read(navigationBarProvider.notifier).onSideChange(value);
              },
              left: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: const Row(
                  children: [
                    Sidebar(
                      guildId: Snowflake.zero,
                    ),
                    Expanded(child: Expanded(child: PrivateMessages()))
                  ],
                ),
              ),
              main: (widget.channelId != null)
                  ? MessageView(
                      guildId: Snowflake.zero,
                      channelId: widget.channelId!,
                    )
                  : const SizedBox(),
              right: (widget.channelId != null)
                  ? MemberList(
                      guildId: Snowflake.zero,
                      channelId: widget.channelId!,
                    )
                  : const SizedBox(),
            );
          }
        },
      ),
    );
  }
}
