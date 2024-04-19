import 'dart:io';

import 'package:bonfire/features/auth/data/repositories/auth.dart';
import 'package:bonfire/features/auth/data/repositories/discord_auth.dart';
import 'package:bonfire/features/auth/models/auth.dart';
import 'package:bonfire/shared/repositories/firebridge/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_storage/get_storage.dart';

void main() async {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    statusBarColor: Colors.transparent,
  ));

  await GetStorage.init();
  runApp(const ProviderScope(child: NavigatorWidget()));
}

class NavigatorWidget extends StatefulWidget {
  const NavigatorWidget({super.key});

  @override
  State<NavigatorWidget> createState() => _NavigatorWidgetState();
}

class _NavigatorWidgetState extends State<NavigatorWidget> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: _buildInitialRouteWidget(),
    );
  }

  Widget _buildInitialRouteWidget() {
    return const AuthWidgetTest();
  }
}

class AuthWidgetTest extends ConsumerStatefulWidget {
  const AuthWidgetTest({super.key});

  @override
  _AuthWidgetTestState createState() => _AuthWidgetTestState();
}

class _AuthWidgetTestState extends ConsumerState<AuthWidgetTest> {
  @override
  Widget build(BuildContext context) {
    final AsyncValue<TestAuth> bruh =
     ref.watch(authProvider(TokenUserAuth(token: Platform.environment['TEST_TOKEN']!)));

    var text = bruh.when(
      data: (data) {
        print("GOT DATA!");
        print(data);
        return data.test;
      },
      loading: () {
        print("loading");
        return "loading";
      },
      error: (error, stack) {
        print("errored");
        print(error);
        return "error";
      },
    );

    return Scaffold(
      body: Center(
        child: ElevatedButton(
            onPressed: () async {
              bruh.when(
                data: (data) {
                  print("GOT DATA!");
                  print(data);
                },
                loading: () {
                  print("loading");
                },
                error: (error, stack) {
                  print("errored");
                  print(error);
                },
              );
            },
            child: Text(text)),
      ),
    );
  }
}
