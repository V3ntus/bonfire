import 'package:bonfire/colors.dart';
import 'package:bonfire/components/sidebar/sidebar.dart';
import 'package:bonfire/globals.dart';
import 'package:bonfire/views/home/channels.dart';
import 'package:bonfire/views/home/messages/messages.dart';
import 'package:bonfire/views/home/overlapping_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nyxx/nyxx.dart';
import 'package:signals/signals.dart';
import 'package:flutter_keyboard_size/flutter_keyboard_size.dart';
import 'dart:io' show Platform;

class Home extends StatelessWidget {
  NyxxGateway client;
  Home({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    globalClient = client;

    return MainPage();
  }
}

class MainPage extends StatefulWidget {
  MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardSizeProvider(
        child: Scaffold(
            resizeToAvoidBottomInset: false,
            body: (Platform.isAndroid | Platform.isIOS)
                ? OverlappingPanels(
                    left: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: Row(
                        children: [
                          Sidebar(),
                          const Expanded(child: ChannelList())
                        ],
                      ),
                    ),
                    main: Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(color: foreground, boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 5,
                          blurRadius: 7,
                          offset: const Offset(0, 3),
                        )
                      ]),
                      child: Messages(),
                    ))
                : Row(
                    children: [
                      Sidebar(),
                      const SizedBox(width: 300, child: ChannelList()),
                      Expanded(child: Messages())
                    ],
                  )));
  }
}
