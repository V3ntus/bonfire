import 'package:bonfire/features/channels/views/channels.dart';
import 'package:bonfire/features/guild/repositories/guilds.dart';
import 'package:bonfire/features/guild/views/guild_overview.dart';
import 'package:bonfire/features/members/views/member_list.dart';
import 'package:bonfire/features/messaging/repositories/messages.dart';
import 'package:bonfire/features/messaging/repositories/realtime_messages.dart';
import 'package:bonfire/features/messaging/views/messages.dart';
import 'package:bonfire/features/overview/controllers/navigation_bar.dart';
import 'package:bonfire/features/overview/views/navigator.dart';
import 'package:bonfire/features/overview/views/overlapping_panels.dart';
import 'package:bonfire/features/overview/views/sidebar.dart';
import 'package:bonfire/theme/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeState();
}

class _HomeState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      ref.watch(realtimeMessagesProvider).when(
          data: (value) {
            ref.read(messagesProvider.notifier).processRealtimeMessages(value);
          },
          loading: () {},
          error: (error, stackTrace) {
            // trust me bro
          });
    });

    return Scaffold(
        body: PopUpNavigationBar(
            panel: OverlappingPanels(
      onSideChange: (value) {
        ref.read(navigationBarProvider.notifier).onSideChange(value);
      },
      left: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: const Row(
          children: [
            Sidebar(),
            Expanded(
              child: Expanded(child: ChannelsList())
            )
          ],
        ),
      ),
      main: const MessageView(),
      right: const MemberList(),
    )));
  }
}
