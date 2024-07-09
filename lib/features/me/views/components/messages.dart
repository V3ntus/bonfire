import 'package:bonfire/features/me/controllers/settings.dart';
import 'package:bonfire/features/me/views/components/member_card.dart';
import 'package:bonfire/features/me/views/components/overview_card.dart';
import 'package:bonfire/features/overview/views/sidebar.dart';
import 'package:bonfire/theme/theme.dart';
import 'package:firebridge/firebridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_platform/universal_platform.dart';

class PrivateMessages extends ConsumerStatefulWidget {
  const PrivateMessages({super.key});

  @override
  ConsumerState<PrivateMessages> createState() => _MessageOverviewState();
}

class _MessageOverviewState extends ConsumerState<PrivateMessages> {
  @override
  Widget build(BuildContext context) {
    var topPadding = MediaQuery.of(context).padding.top;
    double bottomPadding = UniversalPlatform.isMobile
        ? MediaQuery.of(context).padding.bottom + 68
        : 0;
    var dms = ref.watch(privateMessageHistoryProvider).toList();
    var readStates = ref.watch(channelReadStateProvider) ?? {};
    // print(readStates[dms[0].id]?.lastViewed);

    // this is wrong, but until I figure out read states it's what it is.
    dms.sort((a, b) {
      var aReadState = readStates[a.id]?.lastViewed ?? 0;
      var bReadState = readStates[b.id]?.lastViewed ?? 0;
      return -aReadState.compareTo(bReadState);
    });

    return Scaffold(
      body: Padding(
          padding:
              EdgeInsets.only(left: 8, top: topPadding, bottom: bottomPadding),
          child: SizedBox(
              width: double.infinity,
              child: Container(
                  decoration: BoxDecoration(
                      color: Theme.of(context)
                          .custom
                          .colorTheme
                          .channelListBackground,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        bottomLeft: Radius.circular(24),
                      ),
                      border: Border(
                          bottom: BorderSide(
                              color: Theme.of(context)
                                  .custom
                                  .colorTheme
                                  .foreground,
                              width: 1.0))),
                  child: Column(
                    children: [
                      const OverviewCard(),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: dms.length,
                          itemBuilder: (context, index) {
                            return DirectMessageMember(
                              privateChannel: dms[index],
                            );
                          },
                        ),
                      ),
                    ],
                  )))),
    );
  }
}