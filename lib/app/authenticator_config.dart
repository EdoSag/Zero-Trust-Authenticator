import 'package:flutter/material.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// The Authenticator's accent in the suite (sky blue). The brand seed
/// (indigo) is shared by every app.
const Color authenticatorAccent = Color(0xFF0EA5E9);

/// Authenticator in the suite. Not in the core's `ZtSuite` list yet, so the
/// other apps don't link to it before it's released.
const ZtSuiteApp authenticatorSuiteApp = ZtSuiteApp(
  appId: 'authenticator',
  name: 'Authenticator',
  tagline: 'Sign-in codes for your accounts',
  icon: Icons.pin_outlined,
  accent: authenticatorAccent,
  androidPackage: 'dev.sagron.zerotrustauthenticator',
);

/// Locks after one minute away rather than the suite's five: what it holds
/// opens every other account.
const ZtAppConfig authenticatorAppConfig = ZtAppConfig(
  appId: 'authenticator',
  displayName: 'Zero-Trust Authenticator',
  accent: authenticatorAccent,
  autoLockAfter: Duration(minutes: 1),
);
