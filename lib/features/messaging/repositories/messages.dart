import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bonfire/features/auth/data/repositories/auth.dart';
import 'package:bonfire/features/auth/data/repositories/discord_auth.dart';
import 'package:bonfire/features/channels/controllers/channel.dart';
import 'package:bonfire/features/guild/controllers/guild.dart';
import 'package:firebridge_extensions/firebridge_extensions.dart';
import 'package:flutter/widgets.dart';
import 'package:firebridge/firebridge.dart';
import 'package:get_storage/get_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/scheduler.dart';

part 'messages.g.dart';

/// Message provider for fetching messages from the Discord API
@Riverpod(keepAlive: false)
class Messages extends _$Messages {
  AuthUser? user;
  bool listenerRunning = false;
  Map<Channel, Message?> oldestMessage = {};
  DateTime lastFetchTime = DateTime.now();

  final _cacheManager = CacheManager(
    Config(
      'messages',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 10000,
    ),
  );
  Map<String, List<Message>> channelMessagesMap = {};
  bool realtimeListernRunning = false;

  @override
  Future<List<Message>> build() async {
    var authOutput = ref.watch(authProvider.notifier).getAuth();
    var channel = ref.watch(channelControllerProvider);

    if (channel != null) {
      getMessages(authOutput, channel);
      var fromCache = (await getChannelFromCache(channel))!;
      return fromCache;
    }
    return [];
  }

  Future<void> runPreCacheRoutine(Channel channel) async {
    var authOutput = ref.watch(authProvider.notifier).getAuth();
    if (authOutput is AuthUser && channel is TextChannel) {
      var age = await getAgeOfMessageEntry(channel.id.value);
      if (age == null || age.inDays > 1) {
        getMessages(authOutput, channel,
            count: 20, lock: false, requestAvatar: false);
      }
    }
  }

  bool loadingMessages = false;
  Timer lockTimer = Timer(Duration.zero, () {});

  void enableLock() {
    if (loadingMessages) return;
    loadingMessages = true;
    lockTimer = Timer(const Duration(seconds: 1), () {
      loadingMessages = false;
    });
  }

  void removeLock() {
    loadingMessages = false;
    lockTimer.cancel();
  }

  Future<void> getMessages(
    authOutput,
    Channel channel, {
    int? before,
    int? count,
    int? guildId,
    bool? lock = true,
    bool? requestAvatar = true,
  }) async {
    if (loadingMessages == true) return;

    if ((authOutput != null) && (authOutput is AuthUser)) {
      user = authOutput;
      var textChannel = channel as TextChannel;
      var beforeSnowflake = before != null ? Snowflake(before) : null;

      var channelGuildId = guildId ??
          ref.read(guildControllerProvider.notifier).currentGuild!.id.value;

      // if (loadingMessages == true) return;

      if (lock == true) enableLock();

      var selfMember = await user!
          .client.guilds[Snowflake(channelGuildId)].members
          .get(user!.client.user.id);
      var permissions =
          await (textChannel as GuildChannel).computePermissionsFor(selfMember);

      if (permissions.canReadMessageHistory == false) {
        // I think there's still another permission we're missing here...
        // It ocassionally still errors
        print(
            "Error fetching messages in channel ${textChannel.id}, likely do not have access to channel bozo!");
        removeLock();
        return;
      }

      var messages = await textChannel.messages
          .fetchMany(limit: count ?? 20, before: beforeSnowflake);
      // print("Loaded ${messages.length} messages");
      removeLock();

      List<Message> channelMessages = [];
      var completer = Completer<void>();

      int chunkSize = 10;
      int currentIndex = 0;

      void processChunk() {
        int endIndex = currentIndex + chunkSize;
        if (endIndex > messages.length) endIndex = messages.length;

        for (int i = currentIndex; i < endIndex; i++) {
          var message = messages[i];
          if (oldestMessage[channel] == null ||
              message.timestamp.isBefore(oldestMessage[channel]!.timestamp)) {
            oldestMessage[channel] = message;
          }
          var username = message.author.username;
          if (message.author is User) {
            var user = message.author as User;
            username = user.globalName ?? username;
          }

          channelMessages.add(message);
        }

        currentIndex = endIndex;

        if (currentIndex < messages.length) {
          SchedulerBinding.instance?.addPostFrameCallback((_) {
            processChunk();
          });
        } else {
          if (before == null) {
            channelMessagesMap[channel.toString()] = [];
          }
          if (channelMessages.isNotEmpty) {
            channelMessagesMap[channel.toString()]!.addAll(channelMessages);

            if (before == null) {
              cacheMessages(channelMessages, channel.toString());
            }
          }

          if (channel == ref.read(channelControllerProvider)) {
            state = AsyncData(channelMessagesMap[channel.toString()] ?? []);
          }

          completer.complete();
        }
      }

      processChunk();

      return completer.future;
    } else {
      print("no auth output");
    }
  }

  void processRealtimeMessages(List<Message> messages) async {
    if (messages.isNotEmpty) {
      var message = messages.last;
      var channel = message.channel;
      if (channelMessagesMap[channel.toString()] == null) {
        channelMessagesMap[channel.toString()] = [];
      }
      channelMessagesMap[channel.toString()]!.insert(0, message);
      if (channel == ref.read(channelControllerProvider)) {
        // TODO: Only take the first message, and append :D
        // you could also take all of them and compare, to ensure we
        // didn't lose anything in a race condition

        var newState = channelMessagesMap[channel.toString()];
        var cacheKey = channel.toString();

        cacheMessages(messages, cacheKey);
        state = AsyncData(newState ?? []);
      }
    }
  }

  Future<List<Message>?> getChannelFromCache(Channel channel) async {
    // var cacheData = await _cacheManager.getFileFromCache(channel.toString());
    // if (cacheData != null) {
    //   var cachedMessages =
    //       json.decode(utf8.decode(cacheData.file.readAsBytesSync()));
    //   var messagesFuture = (cachedMessages as List<dynamic>).map((e) async {
    //     var message = BonfireMessage.fromJson(e);
    //     var icon = (await fetchMemberAvatarFromCache(message.member.id));
    //     if (icon != null) message.member.icon = Image.memory(icon);

    //     return message;
    //   }).toList();

    //   print("got ${messagesFuture.length} messages from cache");

    //   return await Future.wait(messagesFuture);
    // }
    // no cache
    return null;
  }

  /// Returns the age of the message entry in the cache from [channel]
  Future<Duration?> getAgeOfMessageEntry(int channel) async {
    var cacheData = await _cacheManager.getFileFromCache(channel.toString());
    if (cacheData == null) return null;

    var age = cacheData.file.lastModifiedSync().difference(DateTime.now());
    return age;
  }

  void fetchMoreMessages() {
    // var delta = DateTime.now().difference(lastFetchTime);
    // if (delta.inMilliseconds < 500) return;
    // lastFetchTime = DateTime.now();

    var authOutput = ref.watch(authProvider.notifier).getAuth();
    var channel = ref.watch(channelControllerProvider);
    if (channel != null) {
      getMessages(authOutput, channel,
          before: oldestMessage[channel]!.id.value);
    }
  }

  Future<Uint8List?> fetchMemberAvatarFromCache(String hash) async {
    var cacheData = await _cacheManager.getFileFromCache(hash);
    return cacheData?.file.readAsBytesSync();
  }

  Future<Uint8List> fetchMessageAuthorAvatar(MessageAuthor user) async {
    var cached = await fetchMemberAvatarFromCache(user.avatarHash!);
    if (cached != null) return cached;
    // if (user.avatar != null) return null;
    var iconUrl = user.avatar!.url;
    var fetched = (await http.get(iconUrl)).bodyBytes;

    await _cacheManager.putFile(
      user.avatarHash!,
      fetched,
    );
    return fetched;
  }

  Future<Uint8List> fetchMemberAvatar(Member member) async {
    var cached = await fetchMemberAvatarFromCache(member.user!.avatarHash!);
    if (cached != null) return cached;
    var url = member.user!.avatar.url;
    var fetched = (await http.get(url)).bodyBytes;

    await _cacheManager.putFile(
      member.user!.avatarHash!,
      fetched,
    );
    return fetched;
  }

  Future<void> cacheMessages(List<Message> messages, String cacheKey) async {
    // print("caching messages using key $cacheKey");
    // var toCache = messages;
    // if (toCache.length >= 21) {
    //   toCache = toCache.sublist(0, 20);
    // }
    // await _cacheManager.putFile(
    //   cacheKey,
    //   utf8.encode(json.encode(toCache.map((e) => e.toJson()).toList())),
    // );
  }

  Future<bool> sendMessage(String message, {Channel? channel}) async {
    var authOutput = ref.watch(authProvider.notifier).getAuth();
    Channel? _channel;
    if (channel != null) {
      _channel = channel;
    } else {
      _channel = ref.watch(channelControllerProvider);
    }
    if ((authOutput != null) &&
        (authOutput is AuthUser) &&
        (_channel != null)) {
      user = authOutput;
      var textChannel = _channel as TextChannel;
      await textChannel.sendMessage(MessageBuilder(
        content: message,
      ));
      return true;
    }
    return false;
  }
}
