import 'package:bonfire/features/guild/controllers/guild.dart';
import 'package:bonfire/features/guild/repositories/guilds.dart';
import 'package:bonfire/features/overview/widgets/icon.dart';
import 'package:bonfire/shared/models/guild.dart';
import 'package:bonfire/theme/text_theme.dart';
import 'package:bonfire/theme/theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key});

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  Widget iconBuilder(Guild guild) {
    if (guild.icon != null) {
      return ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(100)),
          child: guild.icon!);
    } else {
      return Container(
          decoration: BoxDecoration(
              color: Theme.of(context).custom.colorTheme.foreground,
              borderRadius: const BorderRadius.all(Radius.circular(100))),
          width: 50,
          height: 50,
          child: Center(
              child: Text(guild.name[0], style: CustomTextTheme().titleSmall)));
    }
  }

  @override
  Widget build(BuildContext context) {
    var guildWatch = ref.watch(guildsProvider);
    var selectedGuildId = ref.watch(guildControllerProvider);

    List<Guild> guildList = [];
    guildWatch.when(
        data: (guilds) {
          guildList = guilds;
        },
        error: (data, trace) {},
        loading: () {});

    return SizedBox(
      width: 60,
      height: double.infinity,
      child: Center(
        child: SizedBox(
            width: 60,
            child: ListView.builder(
              itemCount: guildList.length,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    Stack(
                      children: [
                        (selectedGuildId == guildList[index].id)
                            ? Container(
                                height: 45,
                                width: 4,
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.only(
                                      bottomRight: Radius.circular(8),
                                      topRight: Radius.circular(8),
                                    )),
                              )
                            : const SizedBox(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          child: TextButton(
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0)),
                            onPressed: () {
                              ref
                                  .read(guildControllerProvider.notifier)
                                  .setGuild(guildList[index].id);
                            },
                            child: iconBuilder(guildList[index]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 8,
                    )
                  ],
                );
              },
            )),
      ),
    );
  }
}
