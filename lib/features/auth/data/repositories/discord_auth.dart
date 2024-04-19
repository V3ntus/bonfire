import 'package:bonfire/features/auth/models/auth.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nyxx/nyxx.dart';

class AuthUser extends AuthResponse {
  final NyxxGateway client;
  final String token;

  AuthUser({
    required this.token,
    required this.client,
  });
}

/*
Handle if we need mfa / phone auth / etc
*/
class PartialAuthUser extends AuthResponse {
  final String? token;
  final String? ticket;

  PartialAuthUser({this.token, this.ticket});
}
