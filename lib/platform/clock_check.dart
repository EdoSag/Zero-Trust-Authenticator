import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How far this phone's clock is from the right time (ahead is positive),
/// or null when that could not be found out.
typedef ClockCheck = Future<Duration?> Function();

/// Codes are made from the time, so a phone whose clock is off makes codes
/// that services refuse. Under this much, every service still accepts them.
const clockTolerance = Duration(seconds: 10);

/// Asks the Zero-Trust server (the one the app already syncs with, nobody
/// new) what time it is, from the `Date` line every answer carries, and
/// compares. Good to about a second, which is plenty: codes last 30.
Future<Duration?> checkClockAgainstServer() async {
  final url = dotenv.maybeGet('SUPABASE_URL');
  if (url == null || url.isEmpty) return null;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final sent = DateTime.now();
    final request = await client.headUrl(Uri.parse(url));
    final response = await request.close().timeout(const Duration(seconds: 8));
    final received = DateTime.now();
    await response.drain<void>();
    final header = response.headers.value(HttpHeaders.dateHeader);
    if (header == null) return null;
    return clockOffset(
      sent: sent,
      received: received,
      serverDate: HttpDate.parse(header),
    );
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// The phone's clock minus the server's. The server's time is given in
/// whole seconds, so it is taken as the middle of that second, and the
/// phone's as the middle of the question and the answer.
Duration clockOffset({
  required DateTime sent,
  required DateTime received,
  required DateTime serverDate,
}) {
  final phone = sent.add(received.difference(sent) ~/ 2);
  final server = serverDate.add(const Duration(milliseconds: 500));
  return phone.difference(server);
}

final clockCheckProvider = Provider<ClockCheck>(
  (ref) => checkClockAgainstServer,
);
