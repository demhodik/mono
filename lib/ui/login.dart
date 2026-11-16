import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../api/yandex_api.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets/background.dart';
import 'widgets/glass.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await app.login(_ctrl.text);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: LiquidBackground(child: Stack(children: [
        const Positioned(left: -120, top: -80, child: _Blob(size: 420, alpha: 0.18)),
        const Positioned(right: -100, bottom: -120, child: _Blob(size: 480, alpha: 0.12)),
        const Positioned(left: 0, right: 0, top: 0, height: 48, child: DragToMoveArea(child: SizedBox.expand())),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => windowManager.close(),
          ),
        ),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset('assets/icon.png', width: 56, height: 56),
                    ),
                    const SizedBox(width: 14),
                    const Text('Mono', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1)),
                  ]),
                  const SizedBox(height: 8),
                  const Text('Вход через аккаунт Яндекс Музыки', style: TextStyle(color: C.sub)),
                  const SizedBox(height: 28),
                  const _Step(n: 1, text: 'Нажми кнопку — откроется страница входа Яндекса в браузере.'),
                  const SizedBox(height: 12),
                  GlassButton(
                    onTap: () => launchUrl(Uri.parse(YandexApi.oauthUrl)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.open_in_new_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Открыть вход Яндекса'),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  const _Step(
                      n: 2,
                      text: 'После входа браузер перекинет на страницу музыки. Скопируй ВСЮ ссылку из адресной строки '
                          '(в ней есть access_token) и вставь сюда.'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _ctrl,
                      obscureText: true,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Ссылка или токен',
                        hintStyle: TextStyle(color: C.sub),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Color(0xFFFF8A80))),
                  ],
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GlassButton(
                      active: true,
                      onTap: _busy ? null : _submit,
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                      child: _busy
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text('Войти'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Токен хранится только на этом компьютере.',
                      style: TextStyle(color: C.dim, fontSize: 12)),
                ]),
              ),
            ),
          ),
        ),
      ])),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step({required this.n, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
        child: Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
    ]);
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final double alpha;
  const _Blob({required this.size, required this.alpha});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [Colors.white.withValues(alpha: alpha), Colors.transparent]),
      ),
    );
  }
}
