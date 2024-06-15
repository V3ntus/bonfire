import 'dart:math';

import 'package:bonfire/theme/text_theme.dart';
import 'package:bonfire/theme/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bonfire/features/guild/controllers/current_guild.dart';

class GuildOverview extends ConsumerStatefulWidget {
  const GuildOverview({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _GuildOverviewState();
}

class _GuildOverviewState extends ConsumerState<GuildOverview> {
  @override
  Widget build(BuildContext context) {
    var currentGuild = ref.watch(currentGuildControllerProvider);
    String guildTitle = currentGuild?.name ?? "Not in a server";

    return SizedBox(
        width: double.infinity,
        child: Container(
          decoration: BoxDecoration(
              color: Theme.of(context).custom.colorTheme.foreground,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15), topRight: Radius.circular(8)),
              border: Border(
                  bottom: BorderSide(
                      color: Theme.of(context).custom.colorTheme.brightestGray,
                      width: 1.0))),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 15.0),
                child: Row(
                  children: [
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: Text(
                          overflow: TextOverflow.ellipsis,
                          guildTitle,
                          style: CustomTextTheme().titleSmall.copyWith(
                                color: Colors.white,
                              ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Transform.rotate(
                          angle: pi / 2,
                          child: const Icon(Icons.expand_less_rounded)),
                    )
                  ],
                ),
              ),
              const SizedBox(
                height: 12,
              )
              // Padding(
              //   padding: const EdgeInsets.only(
              //       left: 20, right: 20, top: 8.0, bottom: 8.0),
              //   child: TextButton(
              //     onPressed: () {},
              //     child: Container(
              //       decoration: BoxDecoration(
              //         color: Theme.of(context).custom.colorTheme.brightestGray,
              //         borderRadius:
              //             const BorderRadius.all(Radius.circular(100)),
              //       ),
              //       child: Padding(
              //         padding: const EdgeInsets.all(8.0),
              //         child: Row(
              //           mainAxisAlignment: MainAxisAlignment.center,
              //           children: [
              //             Icon(
              //               Icons.search,
              //               color:
              //                   Theme.of(context).custom.colorTheme.textColor1,
              //             ),
              //             Text(
              //               "Search",
              //               style: CustomTextTheme().bodyText1,
              //             )
              //           ],
              //         ),
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
        ));
  }
}
