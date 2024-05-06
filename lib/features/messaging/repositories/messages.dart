import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bonfire/features/auth/data/repositories/auth.dart';
import 'package:bonfire/features/auth/data/repositories/discord_auth.dart';
import 'package:bonfire/features/channels/controllers/channel.dart';
import 'package:bonfire/features/guild/controllers/guild.dart';
import 'package:bonfire/shared/models/embed.dart';
import 'package:bonfire/shared/models/member.dart';
import 'package:bonfire/shared/models/message.dart';
import 'package:flutter/widgets.dart';
import 'package:nyxx_self/nyxx.dart' as nyxx;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

part 'messages.g.dart';

/*
TODO: get messages when scrolling stop retrieving the correct data when
running the realtime listener
*/

@Riverpod(keepAlive: false)
class Messages extends _$Messages {
  AuthUser? user;
  bool listenerRunning = false;
  Map<int, nyxx.Message?> oldestMessage = {};
  DateTime lastFetchTime = DateTime.now();

  final _cacheManager = CacheManager(
    Config(
      'messages',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 10000,
    ),
  );
  Map<String, List<BonfireMessage>> channelMessagesMap = {};
  bool realtimeListernRunning = false;

  @override
  Future<List<BonfireMessage>> build() async {
    var authOutput = ref.watch(authProvider.notifier).getAuth();
    var channelId = ref.watch(channelControllerProvider);

    if (channelId != null) {
      getMessages(authOutput, channelId);
      var fromCache = (await getChannelFromCache(channelId))!;
      return fromCache;
    }
    return [];
  }

  Future<void> runPreCacheRoutine(nyxx.Channel channel) async {
    var authOutput = ref.watch(authProvider.notifier).getAuth();
    if (authOutput is AuthUser && channel is nyxx.TextChannel) {
      var age = await getAgeOfMessageEntry(channel.id.value);
      if (age == null || age.inDays > 1) {
        getMessages(authOutput, channel.id.value,
            count: 20, lock: false, requestAvatar: false);
      }
    }
  }

  bool loadingMessages = false;
  Timer lockTimer = Timer(Duration.zero, () {});

  void enableLock() {
    if (loadingMessages) return;
    lockTimer = Timer(const Duration(seconds: 3), () {
      loadingMessages = false;
    });
  }

  void removeLock() {
    loadingMessages = false;
    lockTimer.cancel();
  }

  Future<void> getMessages(
    authOutput,
    int channelId, {
    int? before,
    int? count,
    int? guildId,
    bool? lock = true,
    bool? requestAvatar = true,
  }) async {
    if ((authOutput != null) && (authOutput is AuthUser)) {
      user = authOutput;
      var textChannel = await user!.client.channels
          .get(nyxx.Snowflake(channelId)) as nyxx.TextChannel;
      var beforeSnowflake = before != null ? nyxx.Snowflake(before) : null;

      // don't load messages until this one returns
      // the lock only applies if the method itself also intends on locking the request
      if (lock == true) enableLock();

      // load 50 messages, could be 100 max but unnecessary
      var messages = await textChannel.messages
          .fetchMany(limit: count ?? 50, before: beforeSnowflake);
      List<Uint8List> memberAvatars = [];

      if (requestAvatar == true) {
        memberAvatars = await Future.wait(
          messages.map((message) async {
            var avatar = await fetchMemberAvatar(
              BonfireGuildMember(
                id: message.author.id.value,
                name: message.author.username,
                iconUrl: message.author.avatar!.url.toString(),
                displayName: message.author.username,
                guildId: guildId ??
                    ref.read(guildControllerProvider.notifier).currentGuild!.id,
              ),
            );
            return avatar;
          }),
        );
      }
      removeLock();
      List<BonfireMessage> channelMessages = [];
      for (int i = 0; i < messages.length; i++) {
        var message = messages[i];
        if (oldestMessage[channelId] == null ||
            message.timestamp.isBefore(oldestMessage[channelId]!.timestamp)) {
          oldestMessage[channelId] = message;
        }
        var username = message.author.username;
        if (message.author is nyxx.User) {
          var user = message.author as nyxx.User;
          username = user.globalName ?? username;
        }

        List<BonfireEmbed> embeds = [];
        message.embeds.forEach((embed) {
          if (embed.thumbnail != null) {
            embeds.add(BonfireEmbed(
              width: embed.thumbnail!.width!,
              height: embed.thumbnail!.height!,
              thumbnailUrl: embed.thumbnail!.url.toString(),
            ));
          }
        });

        Uint8List? memberAvatar =
            memberAvatars.isNotEmpty ? memberAvatars[i] : null;

        var newMessage = BonfireMessage(
            id: message.id.value,
            channelId: channelId,
            content: message.content,
            timestamp: message.timestamp,
            member: BonfireGuildMember(
              id: message.author.id.value,
              name: message.author.username,
              iconUrl: message.author.avatar!.url.toString(),
              icon: (memberAvatar != null) ? Image.memory(memberAvatar) : null,
              displayName: username,
              guildId: guildId ??
                  ref.read(guildControllerProvider.notifier).currentGuild!.id,
            ),
            embeds: embeds);
        channelMessages.add(newMessage);
      }
      if (before == null) {
        channelMessagesMap[channelId.toString()] = [];
      }
      if (channelMessages.isNotEmpty) {
        channelMessagesMap[channelId.toString()]!.addAll(channelMessages);

        if (before == null) {
          cacheMessages(channelMessages, channelId.toString());
        }
      }

      if (channelId == ref.read(channelControllerProvider)) {
        state = AsyncData(channelMessagesMap[channelId.toString()] ?? []);
      }
    }
  }

  void processRealtimeMessages(List<BonfireMessage> messages) async {
    if (messages.isNotEmpty) {
      var message = messages.last;
      var channelId = message.channelId;
      if (channelMessagesMap[channelId.toString()] == null) {
        channelMessagesMap[channelId.toString()] = [];
      }
      channelMessagesMap[channelId.toString()]!.insert(0, message);
      if (channelId == ref.read(channelControllerProvider)) {
        // TODO: Only take the first message, and append :D
        // you could also take all of them and compare, to ensure we
        // didn't lose anything in a race condition

        var newState = channelMessagesMap[channelId.toString()];
        var cacheKey = channelId.toString();

        cacheMessages(messages, cacheKey);
        state = AsyncData(newState ?? []);
      }
    }
  }

  Future<List<BonfireMessage>?> getChannelFromCache(int channelId) async {
    var cacheData = await _cacheManager.getFileFromCache(channelId.toString());
    if (cacheData != null) {
      var cachedMessages =
          json.decode(utf8.decode(cacheData.file.readAsBytesSync()));
      var messagesFuture = (cachedMessages as List<dynamic>).map((e) async {
        var message = BonfireMessage.fromJson(e);
        var icon = (await fetchMemberAvatarFromCache(message.member.id));
        if (icon != null) message.member.icon = Image.memory(icon);

        return message;
      }).toList();

      print("got ${messagesFuture.length} messages from cache");

      return await Future.wait(messagesFuture);
    }
    // no cache
    return null;
  }

  /// Returns the age of the message entry in the cache from [channelId]
  Future<Duration?> getAgeOfMessageEntry(int channelId) async {
    var cacheData = await _cacheManager.getFileFromCache(channelId.toString());
    if (cacheData == null) return null;

    var age = cacheData.file.lastModifiedSync().difference(DateTime.now());
    return age;
  }

  void fetchMoreMessages() {
    var delta = DateTime.now().difference(lastFetchTime);
    if (delta.inMilliseconds < 500) return;
    lastFetchTime = DateTime.now();

    var authOutput = ref.watch(authProvider.notifier).getAuth();
    var channelId = ref.watch(channelControllerProvider);
    if (channelId != null) {
      getMessages(authOutput, channelId,
          before: oldestMessage[channelId]!.id.value);
    }
  }

  Future<Uint8List?> fetchMemberAvatarFromCache(int userId) async {
    var cacheData = await _cacheManager.getFileFromCache(userId.toString());
    return cacheData?.file.readAsBytesSync();
  }

  Future<Uint8List> fetchMemberAvatar(BonfireGuildMember user) async {
    // var cached = await fetchMemberAvatarFromCache(user.id);
    // if (cached != null) return cached;
    // if (user.avatar != null) return null;
    var icon_url = user.iconUrl;
    var fetched = (await http.get(Uri.parse(icon_url))).bodyBytes;

    await _cacheManager.putFile(
      user.id.toString(),
      fetched,
    );
    return fetched;
  }

  Future<void> cacheMessages(
      List<BonfireMessage> messages, String cacheKey) async {
    print("caching messages using key $cacheKey");
    var toCache = messages;
    if (toCache.length >= 21) {
      toCache = toCache.sublist(0, 20);
    }
    await _cacheManager.putFile(
      cacheKey,
      utf8.encode(json.encode(toCache.map((e) => e.toJson()).toList())),
    );
  }

  Future<bool> sendMessage(String message, {int? channelId}) async {
    var authOutput = ref.watch(authProvider.notifier).getAuth();
    int? _channelId;
    if (channelId != null) {
      _channelId = channelId;
    } else {
      _channelId = ref.watch(channelControllerProvider);
    }
    if ((authOutput != null) &&
        (authOutput is AuthUser) &&
        (_channelId != null)) {
      user = authOutput;
      var textChannel = await user!.client.channels
          .get(nyxx.Snowflake(_channelId)) as nyxx.TextChannel;
      await textChannel.sendMessage(nyxx.MessageBuilder(
        content: message,
      ));
      return true;
    }
    return false;
  }
}
