import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:io' show Platform;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ──────────────────────────────────────────────
// MOTO RACE XTREME
// App que carga el juego HTML5 desde assets local
// ──────────────────────────────────────────────

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  try {
    Firebase.initializeApp();
  } catch (e) {
    debugPrint('❌ Firebase init error: $e');
  }

  // Inicializar AdMob
  MobileAds.instance.initialize();

  // Edge-to-edge en mobile
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF0a0a1a),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  runApp(const MotoRaceApp());
}

class MotoRaceApp extends StatelessWidget {
  const MotoRaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moto Race Xtreme',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _gameReady = false;
  String? _error;
  String? _fcmToken;

  // AdMob
  BannerAd? _bannerAd;
  bool _bannerAdLoaded = false;
  InterstitialAd? _interstitialAd;
  bool _interstitialShown = false;
  int _gameCount = 0;

  static const String _apiBaseUrl = 'http://161.97.74.198/moto_racer_extreme';

  // AdMob IDs
  static const String _bannerAdUnitId = 'ca-app-pub-7277241406857965/9182108330';
  static const String _interstitialAdUnitId = 'ca-app-pub-7277241406857965/9413208474';

  @override
  void initState() {
    super.initState();
    _initGame();
    _loadBannerAd();
    _loadInterstitialAd();
  }

  Future<void> _initGame() async {
    // Obtener info del paquete (para versión)
    try {
      final info = await PackageInfo.fromPlatform();
      debugPrint('📦 Moto Race Xtreme v${info.version}');
    } catch (_) {}

    // Obtener FCM token
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      _fcmToken = await messaging.getToken();
      debugPrint('📱 FCM Token: $_fcmToken');

      messaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        debugPrint('🔄 FCM renovado: $token');
      });
    } catch (e) {
      debugPrint('❌ FCM error: $e');
    }

    setState(() => _isLoading = false);
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: _bannerAdUnitId,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _bannerAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          Future.delayed(const Duration(seconds: 30), _loadBannerAd);
        },
      ),
      request: const AdRequest(),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) {
          Future.delayed(const Duration(seconds: 60), _loadInterstitialAd);
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_interstitialAd == null || _interstitialShown) return;
    _interstitialShown = true;
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _interstitialShown = false;
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _interstitialShown = false;
      },
    );
    _interstitialAd!.show();
  }

  // Called from JS when game starts
  void _onGameStart() {
    _gameCount++;
  }

  // Called from JS when game ends
  void _onGameOver() {
    // Show interstitial every 3 games
    if (_gameCount % 3 == 0) {
      _showInterstitialAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFFFDD00)),
              SizedBox(height: 20),
              Text('Cargando Moto Race Xtreme...',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0a0a1a),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? _buildError()
                : Stack(
                    children: [
                      _buildWebView(),
                      if (!_gameReady) _buildLoadingOverlay(),
                    ],
                  ),
          ),
          // Banner Ad
          if (_bannerAdLoaded && _bannerAd != null)
            Container(
              color: const Color(0xFF0a0a1a),
              child: Center(
                child: SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Color(0xFFFF4444)),
          const SizedBox(height: 20),
          const Text('Error al cargar el juego',
              style: TextStyle(color: Colors.white70, fontSize: 18)),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.white38, fontSize: 14),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _error = null;
                _gameReady = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFDD00),
              foregroundColor: const Color(0xFF1a1a2e),
            ),
            child: const Text('REINTENTAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: const Color(0xFF0a0a1a),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icon/logo.png',
              width: 120,
              height: 120,
              errorBuilder: (_, __, ___) => const Icon(Icons.sports_motorsports,
                  size: 80, color: Color(0xFFFFDD00)),
            ),
            const SizedBox(height: 24),
            const Text('MOTO RACE XTREME',
                style: TextStyle(
                  fontFamily: 'Monospace',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFDD00),
                  letterSpacing: 4,
                )),
            const SizedBox(height: 16),
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFDD00)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useHybridComposition: true,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        allowsInlineMediaPlayback: true,
        transparentBackground: false,
        isInspectable: true,
        geolocationEnabled: false,
        applicationNameForUserAgent: 'MotoRaceXtreme-App',
        // Permitir acceso a assets local
        allowFileAccessFromFileURLs: true,
        allowUniversalAccessFromFileURLs: true,
        // Permitir contenido mixto (HTTP desde HTTPS base)
        // Sin cache para que el juego siempre cargue fresco
        cacheEnabled: false,
      ),
      initialData: InAppWebViewInitialData(
        data: _buildGameHtml(),
        mimeType: 'text/html',
        encoding: 'utf-8',
        // about:blank evita bloqueos de HTTP y el juego carga desde adentro
        baseUrl: WebUri('about:blank'),
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;

        // Registrar handlers para comunicación JS -> Flutter
        controller.addJavaScriptHandler(
          handlerName: 'onGameStart',
          callback: (args) {
            _onGameStart();
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'onGameOver',
          callback: (args) {
            _onGameOver();
          },
        );
      },
      onLoadStart: (controller, url) {
        debugPrint('📄 Cargando juego: $url');
      },
      onLoadStop: (controller, url) async {
        debugPrint('✅ Juego cargado: $url');

        // Inyectar JS para comunicar eventos de juego a Flutter
        await controller.evaluateJavascript(source: '''
(function() {
  // Interceptar game over
  const _origGo = window.go;
  if (_origGo) {
    window.go = function() {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('onGameOver');
      }
      _origGo();
    };
  }

  // Interceptar start
  const _origSt = window.st;
  if (_origSt) {
    window.st = function(lv) {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('onGameStart');
      }
      _origSt(lv);
    };
  }
})();
''');

        // Pequeña pausa y luego ocultar el overlay de carga
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() => _gameReady = true);
        }
      },
      onReceivedError: (controller, request, error) {
        debugPrint('❌ Error: ${error.description}');
        if (mounted) {
          setState(() {
            _gameReady = true;
            _error = error.description;
          });
        }
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url.toString();
        // Permitir todas las URLs del juego (incluye API calls)
        return NavigationActionPolicy.ALLOW;
      },
    );
  }

  /// Construye el HTML del juego, reemplazando la URL de la API
  /// para que apunte al servidor remoto.
  String _buildGameHtml() {
    // Leer el HTML original del juego desde assets
    // Como no podemos leer assets desde Dart fácilmente sin AssetBundle,
    // vamos a cargarlo inline con la API URL modificada
    try {
      return _gameHtmlContent;
    } catch (e) {
      debugPrint('❌ Error cargando juego: $e');
      _error = 'Error cargando juego: $e';
      return '<html><body><h1>Error</h1></body></html>';
    }
  }

  String get _gameHtmlContent => '''<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no">
<title>Moto Racer Extreme</title>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
<link href="https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700;900&family=Rajdhani:wght@400;600;700&display=swap" rel="stylesheet">
<style>
${_gameCss}
</style>
</head>
<body>
<div id="game-wrapper">
<div id="game-container">
<canvas id="game-canvas"></canvas>
${_gameHtml}
</div>
</div>
<script>
${_gameJs}
</script>
</body>
</html>''';

  String get _gameCss => '''*{margin:0;padding:0;box-sizing:border-box;touch-action:manipulation;user-select:none}
:root{--ny:#ffdd00;--no:#ff6b00;--nb:#00d4ff}
body{font-family:'Rajdhani',sans-serif;background:#0a0a1a;min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;color:#fff;padding:0;margin:0;overflow:hidden}
#game-wrapper{width:100%;max-width:100%;margin:0 auto;padding:0}
#game-container{position:relative;width:100%;height:100vh;background:linear-gradient(180deg,#0d1b3e,#1a1a3e);overflow:hidden;border-radius:0}
#game-canvas{display:block;width:100%;height:100%}
.screen{position:absolute;top:0;left:0;width:100%;height:100%;display:none;flex-direction:column;justify-content:center;align-items:center;background:rgba(5,5,20,.94);z-index:20;padding:20px;text-align:center}
.screen.active{display:flex}
#start-screen{background:radial-gradient(ellipse at top,rgba(255,221,0,.06) 0%,rgba(5,5,20,1) 70%)}
.game-logo{font-family:'Orbitron',sans-serif;font-size:4.5rem;font-weight:900;color:var(--ny);text-shadow:0 0 30px rgba(255,221,0,.5);margin-bottom:10px;letter-spacing:4px}
.game-logo span{color:var(--no)}
.game-subtitle{font-size:1.8rem;color:rgba(255,255,255,.5);margin-bottom:30px;letter-spacing:6px;text-transform:uppercase}
.color-selector{margin-bottom:10px}
.color-selector p{color:rgba(255,255,255,.6);font-size:1.5rem;margin-bottom:14px}
.difficulty-selector{margin-bottom:18px}
.difficulty-selector p{color:rgba(255,255,255,.5);font-size:1.1rem;margin-bottom:10px}
.diff-btn{background:transparent;border:2px solid rgba(255,255,255,.15);padding:14px 30px;border-radius:30px;color:rgba(255,255,255,.5);font-size:1.3rem;font-weight:600;cursor:pointer;margin:5px;font-family:'Rajdhani',sans-serif;transition:all .2s}
.diff-btn.selected{background:rgba(255,221,0,.15);border-color:var(--ny);color:var(--ny)}
.diff-btn:hover{border-color:rgba(255,221,0,.5);color:rgba(255,255,255,.8)}
#color-options{display:flex;gap:10px;justify-content:center;flex-wrap:wrap}
.color-swatch{width:64px;height:64px;border-radius:50%;border:4px solid transparent;cursor:pointer;transition:all .2s}
.color-swatch:hover{transform:scale(1.2)}
.color-swatch.active{border-color:#fff;box-shadow:0 0 12px rgba(255,255,255,.4);transform:scale(1.1)}
.game-btn{background:linear-gradient(135deg,var(--ny),var(--no));border:none;padding:24px 70px;border-radius:50px;color:#1a1a2e;font-size:2rem;font-weight:700;cursor:pointer;box-shadow:0 6px 25px rgba(255,221,0,.35);margin:8px;font-family:'Rajdhani',sans-serif}
.game-btn-second{background:transparent;border:2px solid rgba(255,255,255,.2);padding:16px 40px;border-radius:50px;color:#fff;font-size:1.4rem;font-weight:600;cursor:pointer;margin:5px}
#top3-scores{margin-top:16px;width:100%;max-width:320px}
.top3-row{display:flex;align-items:center;justify-content:space-between;padding:6px 12px;margin:3px 0;border-radius:8px;background:rgba(255,255,255,.04)}
.top3-row.gold{background:rgba(255,215,0,.1);border:1px solid rgba(255,215,0,.2)}
.top3-row.silver{background:rgba(192,192,192,.06);border:1px solid rgba(192,192,192,.12)}
.top3-row.bronze{background:rgba(205,127,50,.06);border:1px solid rgba(205,127,50,.12)}
.top3-rank{font-family:'Orbitron',sans-serif;font-weight:700;font-size:.9rem;width:22px;text-align:center}
.top3-rank.gold{color:#ffd700}.top3-rank.silver{color:#c0c0c0}.top3-rank.bronze{color:#cd7f32}
.top3-name{flex:1;font-weight:600;font-size:.85rem;color:rgba(255,255,255,.8);padding:0 8px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.top3-score{font-family:'Orbitron',sans-serif;font-weight:700;font-size:.9rem;color:var(--ny)}
.top3-empty{text-align:center;color:rgba(255,255,255,.15);font-size:.8rem;padding:8px}
.top3-title{font-size:.75rem;color:rgba(255,255,255,.25);text-transform:uppercase;letter-spacing:3px;margin-bottom:6px;text-align:center}
#top-bar{position:absolute;top:0;left:0;width:100%;display:flex;justify-content:space-between;align-items:center;padding:12px 16px;z-index:10;background:linear-gradient(180deg,rgba(0,0,0,.7) 0%,transparent 100%)}
#top-center{display:flex;gap:10px;align-items:center}
#pause-btn,#home-btn-top{background:rgba(0,0,0,.5);border:none;width:58px;height:58px;border-radius:50%;color:#fff;font-size:1.5rem;cursor:pointer}
#pause-btn{color:var(--ny)}
#home-btn-top{color:#ff6666}
#score-label{font-size:1.2rem;color:rgba(255,255,255,.5);text-transform:uppercase;letter-spacing:2px}
#score-value{font-family:'Orbitron',sans-serif;font-size:3.2rem;font-weight:700;color:var(--ny);text-shadow:0 0 10px rgba(255,221,0,.3);line-height:1}
#level-badge{background:rgba(255,255,255,.1);border:1px solid rgba(0,212,255,.3);padding:8px 18px;border-radius:20px;font-size:1.3rem;color:var(--nb);margin-top:4px;display:inline-block}
#top-right{display:flex;gap:12px;align-items:center}
#hearts-display{display:flex;gap:8px;align-items:center;margin-right:8px}
#hearts-display .heart{font-size:3.2rem;color:#ff4444;text-shadow:0 0 6px rgba(255,0,0,.4);transition:all .3s}
#hearts-display .heart.lost{color:rgba(255,255,255,.15);text-shadow:none}
@keyframes levelPop{0%{transform:scale(1);box-shadow:0 0 0 var(--ny)}50%{transform:scale(1.3);box-shadow:0 0 25px var(--ny)}100%{transform:scale(1);box-shadow:0 0 0 var(--ny)}}
@keyframes heartPop{0%{transform:scale(1);text-shadow:0 0 4px #f44}50%{transform:scale(1.5);text-shadow:0 0 20px #f44}100%{transform:scale(1);text-shadow:0 0 4px #f44}}
@keyframes scorePop{0%{transform:scale(1)}50%{transform:scale(1.4);text-shadow:0 0 25px var(--ny)}100%{transform:scale(1)}}
.level-flash{animation:levelPop .5s ease-out}
.heart-flash{animation:heartPop .4s ease-out}
.score-flash{animation:scorePop .5s ease-out}
#sound-btn,#leaderboard-btn{background:rgba(0,0,0,.5);border:none;width:74px;height:74px;border-radius:50%;color:#fff;font-size:2.2rem;cursor:pointer}
#leaderboard-btn{color:var(--ny)}
#time-indicator{position:absolute;top:96px;right:12px;background:rgba(0,0,0,.5);padding:6px 14px;border-radius:12px;font-size:1rem;color:rgba(255,255,255,.6);z-index:10}
#gameover-screen{background:radial-gradient(ellipse at center,rgba(200,0,0,.15) 0%,rgba(5,5,20,.97) 70%)}
#gameover-screen h2{font-family:'Orbitron',sans-serif;font-size:3rem;color:#ff4444;text-shadow:0 0 20px rgba(255,0,0,.3)}
.final-stats{display:flex;gap:15px;margin:15px 0;flex-wrap:wrap;justify-content:center}
.stat-card{background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.1);padding:12px 18px;min-width:90px}
.stat-card .num{font-family:'Orbitron',sans-serif;font-size:1.5rem;font-weight:700;color:var(--ny)}
.stat-card .lbl{font-size:.75rem;color:rgba(255,255,255,.5);text-transform:uppercase;letter-spacing:1px}
#levelup-screen{background:radial-gradient(ellipse at center,rgba(255,221,0,.1) 0%,rgba(5,5,20,.95) 70%)}
#levelup-screen h2{font-family:'Orbitron',sans-serif;font-size:2.4rem;color:var(--ny);text-shadow:0 0 20px rgba(255,221,0,.4)}
.level-big{font-size:5rem;font-family:'Orbitron',sans-serif;font-weight:900;color:var(--ny);text-shadow:0 0 30px rgba(255,221,0,.5)}
#leaderboard-modal{position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,.85);z-index:100;display:none;justify-content:center;align-items:center;padding:20px}
#leaderboard-modal.active{display:flex}
.lb-content{background:linear-gradient(180deg,#1a1a3e,#0a0a1a);border-radius:20px;border:1px solid rgba(255,221,0,.15);width:100%;max-width:420px;max-height:80vh;overflow-y:auto;padding:25px}
.lb-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:15px}
.lb-header h3{font-family:'Orbitron',sans-serif;font-size:1.3rem;color:var(--ny)}
.lb-close{background:none;border:none;color:#fff;font-size:1.5rem;cursor:pointer}
.lb-row{display:flex;align-items:center;padding:10px 12px;border-bottom:1px solid rgba(255,255,255,.05)}
.lb-row.gold{background:rgba(255,215,0,.1)}
.lb-rank{font-weight:700;width:30px;color:rgba(255,255,255,.4)}
.lb-rank.top1{color:#ffd700}.lb-rank.top2{color:#c0c0c0}.lb-rank.top3{color:#cd7f32}
.lb-name{flex:1;font-weight:600;font-size:1rem}
.lb-score{font-family:'Orbitron',sans-serif;font-weight:700;color:var(--ny);font-size:1.1rem}
.lb-me{color:var(--nb)!important}
.lb-loading,.lb-empty{text-align:center;color:rgba(255,255,255,.3);padding:20px}
.score-popup{position:absolute;color:var(--ny);font-weight:700;font-size:1.2rem;font-family:'Orbitron',sans-serif;text-shadow:0 0 8px rgba(255,221,0,.5);pointer-events:none;z-index:15;animation:scoreUp .8s forwards}
@keyframes scoreUp{0%{transform:translateY(0) scale(1);opacity:1}100%{transform:translateY(-60px) scale(1.3);opacity:0}}
.confetti{position:absolute;width:8px;height:8px;animation:confettiDrop 1.5s ease-in forwards;z-index:25;pointer-events:none}
@keyframes confettiDrop{0%{transform:translateY(-20px) rotate(0deg);opacity:1}100%{transform:translateY(100vh) rotate(720deg);opacity:0}}
@media(max-width:400px){.game-logo{font-size:2.6rem}.stat-card{padding:10px 14px;min-width:90px}.stat-card .num{font-size:1.4rem}}
@media(max-height:600px){.game-logo{font-size:2.8rem}.game-subtitle{font-size:1.2rem;margin-bottom:12px}.game-btn{padding:14px 40px;font-size:1.4rem}.color-swatch{width:40px;height:40px}}
''';

  String get _gameHtml => '''<div id="top-bar">
<div id="score-display">
<div id="score-label">Puntos</div>
<div id="score-value">0</div>
<div id="level-badge"><i class="fas fa-bolt"></i> Nivel 1</div>
<div id="player-nick" style="font-size:.75rem;color:rgba(255,255,255,.25);margin-top:2px"></div>
</div>
<div id="top-center">
<button id="pause-btn"><i class="fas fa-pause"></i></button>
<button id="home-btn-top"><i class="fas fa-home"></i></button>
</div>
<div id="top-right">
<div id="hearts-display">
<i class="fas fa-heart heart" id="h1"></i>
<i class="fas fa-heart heart" id="h2"></i>
<i class="fas fa-heart heart" id="h3"></i>
</div>
<button id="leaderboard-btn"><i class="fas fa-trophy"></i></button>
<button id="sound-btn"><i class="fas fa-volume-up"></i></button>
</div>
</div>
<div id="time-indicator"><i class="fas fa-sun"></i> Dia</div>

<div id="start-screen" class="screen active">
<div class="game-logo">MOTO<span>RACER</span></div>
<div class="game-subtitle">Extreme Edition</div>
<div class="color-selector">
<p>🎨 Elige el color de tu moto:</p>
<div id="color-options">
<div class="color-swatch active" data-color="#FFDD00" style="background:#FFDD00"></div>
<div class="color-swatch" data-color="#FF4444" style="background:#FF4444"></div>
<div class="color-swatch" data-color="#448AFF" style="background:#448AFF"></div>
<div class="color-swatch" data-color="#69F0AE" style="background:#69F0AE"></div>
<div class="color-swatch" data-color="#FF69B4" style="background:#FF69B4"></div>
<div class="color-swatch" data-color="#9C27B0" style="background:#9C27B0"></div>
<div class="color-swatch" data-color="#FFFFFF" style="background:#FFFFFF"></div>
</div>
</div>
<div class="difficulty-selector">
<p>⚡ Dificultad:</p>
<button class="diff-btn" data-level="1">Facil</button>
<button class="diff-btn selected" data-level="10">Medio</button>
<button class="diff-btn" data-level="20">Dificil</button>
</div>
<button class="game-btn" id="start-btn"><i class="fas fa-play"></i> JUGAR</button>
<div id="my-nick" style="margin-top:6px;font-size:.85rem;color:rgba(255,255,255,.25);text-align:center"></div>
<div id="top3-scores"></div>
<div style="margin-top:20px;font-size:1rem;color:rgba(255,255,255,.3)"><i class="fas fa-hand-pointer"></i> Desliza para mover la moto</div>
</div>

<div id="gameover-screen" class="screen">
<h2>GAME OVER</h2>
<div class="final-stats">
<div class="stat-card"><div class="num" id="final-score">0</div><div class="lbl">Puntos</div></div>
<div class="stat-card"><div class="num" id="final-level">1</div><div class="lbl">Nivel</div></div>
<div class="stat-card"><div class="num" id="final-passed">0</div><div class="lbl">Esquivados</div></div>
</div>
<div><button class="game-btn" id="restart-btn"><i class="fas fa-redo"></i> REINTENTAR</button></div>
<button class="game-btn-second" id="home-btn"><i class="fas fa-home"></i> Menu Principal</button>
</div>

<div id="levelup-screen" class="screen">
<h2>SUBISTE DE NIVEL</h2>
<div class="level-big" id="new-level">2</div>
<p style="color:rgba(255,255,255,.6);margin-bottom:15px">Mayor velocidad, mas vehiculos!</p>
<button class="game-btn" id="continue-btn"><i class="fas fa-forward"></i> CONTINUAR</button>
</div>

<div id="pause-screen" class="screen">
<h2>⏸ PAUSA</h2>
<div id="pause-stats" style="margin-bottom:20px;text-align:center">
<div id="pause-nick" style="color:rgba(255,255,255,.5);font-size:1.1rem"></div>
<div id="pause-score" style="font-family:'Orbitron',sans-serif;font-size:2.5rem;color:var(--ny);margin-top:8px"></div>
<div id="pause-level" style="color:rgba(255,255,255,.4);font-size:1rem;margin-top:4px"></div>
</div>
<button class="game-btn" id="resume-btn"><i class="fas fa-play"></i> CONTINUAR</button>
<button class="game-btn-second" id="home-from-pause"><i class="fas fa-home"></i> Menu Principal</button>
</div>

<div id="leaderboard-modal">
<div class="lb-content">
<div class="lb-header">
<h3><i class="fas fa-trophy"></i> TOP JUGADORES</h3>
<button class="lb-close" id="lb-close">&times;</button>
</div>
<div id="lb-list"><div class="lb-loading"><i class="fas fa-spinner fa-spin"></i> Cargando...</div></div>
</div>
</div>
''';

  String get _gameJs => '''
const API='$_apiBaseUrl/api.php';
let pid=null,nick='',sound=true, motoColor='#FFDD00',startLevel=10,paused=false,lastScoreMilestone=0;var st;
let cv,ctx,player,veh=[],rl=[],tr=[],bld=[],hearts=[],stars=[];
let sc=0,vp=0,lv=1,lives=3,invuln=0,run=false,sp=5,sr=80,f=0,tod='day',tfn=0,drg=false,lastX=0,lastY=0,W=0,H=0,heartTimer=0,starTimer=0;
const VC=['#FF5252','#448AFF','#69F0AE','#FF4081','#FFC107','#9C27B0'];
const VT=['car','truck','van','bus','person','animal','bicycle','triangle','square','circle'];
function D(id){return document.getElementById(id)}

function init(){
 cv=D('game-canvas');ctx=cv.getContext('2d');sz();
 player={x:cv.width/2,y:cv.height-100,w:26,h:44};
 for(let i=0;i<25;i++){rl.push({x:cv.width/2-80,y:i*40,w:4,h:20});rl.push({x:cv.width/2,y:i*40,w:4,h:20});rl.push({x:cv.width/2+80,y:i*40,w:4,h:20})}
 for(let i=0;i<15;i++){tr.push({x:cv.width/6-40,y:i*80-80,tran:Math.floor(Math.random()*4)});tr.push({x:cv.width*5/6+40,y:i*80-80,tran:Math.floor(Math.random()*4)})}
 for(let i=0;i<18;i++){
  const bw=35+Math.floor(Math.random()*20),bh=55+Math.floor(Math.random()*55);
  const bc=['#e74c3c','#3498db','#f39c12','#2ecc71','#9b59b6','#1abc9c','#e67e22','#95a5a6','#d35400'][Math.floor(Math.random()*9)];
  const roof=Math.random()>.6;
  const winCnt=Math.floor(Math.random()*3)+1;
  bld.push({side:0,x:15+Math.random()*20,y:i*130-80,w:bw,h:bh,color:bc,roof,winCnt,balc:Math.random()>.7});
  bld.push({side:1,x:cv.width-35-Math.random()*20,y:i*130-80,w:bw,h:bh,color:bc,roof,winCnt,balc:Math.random()>.7})}
 
 document.querySelectorAll('.color-swatch').forEach(el=>{
  el.addEventListener('click',()=>{
   document.querySelectorAll('.color-swatch').forEach(s=>s.classList.remove('active'));
   el.classList.add('active');motoColor=el.dataset.color;playClick()
  })
 });
 
 document.querySelectorAll('.diff-btn').forEach(b=>b.addEventListener('click',()=>{
  document.querySelectorAll('.diff-btn').forEach(x=>x.classList.remove('selected'));
  b.classList.add('selected');startLevel=parseInt(b.dataset.level);playClick()
 }));
 D('start-btn').onclick=()=>{playClick();st(startLevel)};
 D('restart-btn').onclick=()=>{playClick();st(startLevel)};
 D('home-btn').onclick=()=>{playClick();run=false;D('gameover-screen').classList.remove('active');D('start-screen').classList.add('active');loadTop3()};
 D('pause-btn').onclick=()=>{
  if(!run)return;playClick();paused=true;run=false;
  const ps=D('pause-score'),pl=D('pause-level'),pn=D('pause-nick');
  if(ps)ps.textContent=sc;if(pl)pl.textContent='Nivel '+lv;if(pn)pn.textContent='👤 '+nick;
  D('pause-screen').classList.add('active')
 };
 D('resume-btn').onclick=()=>{
  playClick();paused=false;run=true;D('pause-screen').classList.remove('active');lp()
 };
 D('home-btn-top').onclick=()=>{playClick();run=false;paused=false;veh=[];D('gameover-screen').classList.remove('active');D('pause-screen').classList.remove('active');D('start-screen').classList.add('active');loadTop3()};
 D('home-from-pause').onclick=()=>{playClick();run=false;paused=false;veh=[];D('pause-screen').classList.remove('active');D('start-screen').classList.add('active');loadTop3()};
 D('sound-btn').onclick=()=>{sound=!sound;D('sound-btn').innerHTML=sound?'<i class="fas fa-volume-up"></i>':'<i class="fas fa-volume-mute"></i>'};
 D('leaderboard-btn').onclick=()=>{playClick();if(run){paused=true;run=false}lb()};
 D('lb-close').onclick=()=>{D('leaderboard-modal').classList.remove('active');if(paused){paused=false;run=true;lp()}};
 D('leaderboard-modal').onclick=e=>{if(e.target===D('leaderboard-modal')){D('leaderboard-modal').classList.remove('active');if(paused){paused=false;run=true;lp()}}};
 
 const tc=D('game-container');
 tc.addEventListener('touchstart',e=>{
  if(run&&!e.target.closest('#top-bar')&&!e.target.closest('.screen')){e.preventDefault();const r=cv.getBoundingClientRect();const t=e.touches[0];lastX=(t.clientX||t.pageX||0)-r.left;lastY=(t.clientY||t.pageY||0)-r.top;drg=true}
 },{passive:false});
 tc.addEventListener('touchmove',e=>{if(run&&drg){e.preventDefault();mv(e.touches[0])}},{passive:false});
 tc.addEventListener('touchend',e=>{drg=false});
 tc.addEventListener('mousedown',e=>{if(run){const r=cv.getBoundingClientRect();lastX=(e.clientX||e.pageX||0)-r.left;lastY=(e.clientY||e.pageY||0)-r.top;drg=true}});
 tc.addEventListener('mousemove',e=>{if(run&&drg)mv(e)});
 tc.addEventListener('mouseup',e=>{drg=false});
 document.addEventListener('keydown',e=>{if(!run)return;if(e.key==='ArrowLeft')player.x=Math.max(cv.width/6+20,player.x-15);if(e.key==='ArrowRight')player.x=Math.min(cv.width*5/6-20,player.x+15)});
 window.addEventListener('resize',sz);
 drawBg();
}

function mv(e){const r=cv.getBoundingClientRect(),x=(e.clientX||e.pageX||0)-r.left,y=(e.clientY||e.pageY||0)-r.top;
const dx=x-lastX,dy=y-lastY;
player.x=Math.max(cv.width/6+20,Math.min(cv.width*5/6-20,player.x+dx));
player.y=Math.max(cv.height*.35,Math.min(cv.height-40,player.y+dy));
lastX=x;lastY=y}

function sz(){cv.width=cv.offsetWidth;cv.height=cv.offsetHeight;W=cv.width;H=cv.height;if(player){player.x=cv.width/2;player.y=cv.height-100}}

function upHearts(){
 for(let i=1;i<=3;i++){const h=D('h'+i);if(i<=lives){h.className='fas fa-heart heart'}else{h.className='fas fa-heart heart lost'}}
}
function flashHeart(idx){
 const h=D('h'+idx);if(!h)return;h.classList.remove('heart-flash');void h.offsetWidth;h.classList.add('heart-flash');setTimeout(()=>h.classList.remove('heart-flash'),500)
}

st=function(lv0){lv0=lv0||1;
 sc=0;vp=0;lv=lv0;lives=3;invuln=0;veh=[];hearts=[];stars=[];run=true;sp=5+(lv0-1)*.5;sr=Math.max(30,80-(lv0-1)*15);f=0;heartTimer=0;starTimer=0;lastScoreMilestone=0;
 tod='day';tfn=0;upHearts();ui();
 D('start-screen').classList.remove('active');
 D('gameover-screen').classList.remove('active');
 D('levelup-screen').classList.remove('active');
 playEngine();setTimeout(lp,800)
}

async function sv(){
 if(!pid)return;
 try{const fd=new FormData();fd.append('player_id',pid);fd.append('score',sc);fd.append('level',lv);fd.append('vehicles_passed',vp);
 await fetch(API+'?action=save_score',{method:'POST',body:fd})}catch(e){}
}
function go(){
 run=false;
 D('final-score').textContent=sc;
 D('final-level').textContent=lv;
 D('final-passed').textContent=vp;
 D('gameover-screen').classList.add('active');
 playGameOver();sv();setTimeout(loadTop3,500)
}

function hit(){
 if(invuln>0)return;
 lives--;
 upHearts();flashHeart(lives+1);
 playHit();
 if(lives<=0){go();return}
 invuln=150
}

function lu(){
 lv++;sp+=0.5;sr=Math.max(30,sr-15);f=5;ui();playLevelup();cf();flashLevel()
}
function flashLevel(){
 const lb=D('level-badge');lb.classList.remove('level-flash');void lb.offsetWidth;lb.classList.add('level-flash');setTimeout(()=>lb.classList.remove('level-flash'),600)
}

function ui(){
 D('score-value').textContent=sc;
 if(sc>0&&sc%1000===0&&sc!==lastScoreMilestone){lastScoreMilestone=sc;const s=D('score-value');s.classList.remove('score-flash');void s.offsetWidth;s.classList.add('score-flash');setTimeout(()=>s.classList.remove('score-flash'),600);cf()}
 D('level-badge').innerHTML='<i class="fas fa-bolt"></i> Nivel '+lv
}

function lp(){
 if(!run)return;td();const c=gc();
 ctx.fillStyle=c.env;ctx.fillRect(0,0,W,H);
 ctx.fillStyle=c.road;ctx.fillRect(W/6,0,W*2/3,H);
 ctx.fillStyle=c.rl;ctx.fillRect(W/6,0,3,H);ctx.fillRect(W*5/6-3,0,3,H);
 ut(c);ub(c);ur(c);uv();uh();us();dp();
 if(invuln>0)invuln--;
 if(vp>0&&vp%15===0&&f%60===0){lu()}
 f++;if(f%sr===0)sv2();
 heartTimer++;
 if(heartTimer>500&&Math.random()<.008){heartTimer=0;spawnHeart()}
 starTimer++;
 if(starTimer>700&&Math.random()<.005){starTimer=0;spawnStar()}
 requestAnimationFrame(lp)
}

function td(){
 tfn++;if(tfn>=1200){tfn=0;tod=tod==='day'?'night':'day';
 const ic=tod==='day'?'fa-sun':'fa-moon',lb=tod==='day'?'Dia':'Noche';
 D('time-indicator').innerHTML='<i class="fas '+ic+'"></i> '+lb}}

function gc(){
 if(tod==='day')return{road:'#2c3e50',env:'#1a1a2e',rl:'rgba(255,255,255,.6)',t1:'#8B4513',c1:'#2E8B57',c2:'#3CB371',c3:'#228B22'}
 return{road:'#1a1a2e',env:'#050510',rl:'rgba(100,100,150,.2)',t1:'#2a1a0a',c1:'#1a2a1a',c2:'#1a2a2a',c3:'#1a1a2a'}}

function ub(c){
 for(const b of bld){
  b.y+=sp*.8;if(b.y>H+60)b.y=-120;
  ctx.fillStyle=b.color;ctx.fillRect(b.x,b.y,b.w,b.h);
  ctx.strokeStyle='rgba(0,0,0,.15)';ctx.lineWidth=1;ctx.strokeRect(b.x,b.y,b.w,b.h);
  if(b.roof){
   ctx.fillStyle='rgba(0,0,0,.2)';ctx.beginPath();ctx.moveTo(b.x-5,b.y);ctx.lineTo(b.x+b.w/2,b.y-18);ctx.lineTo(b.x+b.w+5,b.y);ctx.closePath();ctx.fill()
  }else{
   ctx.fillStyle='rgba(0,0,0,.15)';ctx.fillRect(b.x,b.y,b.w,4)
  }
  for(let w=0;w<b.winCnt;w++){
   const wy=b.y+12+w*14;
   ctx.fillStyle='#ffe082';ctx.shadowColor='#ffe082';ctx.shadowBlur=3;
   ctx.fillRect(b.x+6,b.y+8,8,10);ctx.fillRect(b.x+b.w-14,b.y+8,8,10);
   ctx.fillRect(b.x+6,wy,8,10);ctx.fillRect(b.x+b.w-14,wy,8,10);
   ctx.shadowBlur=0;ctx.fillStyle='rgba(255,255,255,.2)';ctx.fillRect(b.x+7,b.y+9,3,3);ctx.fillRect(b.x+b.w-13,b.y+9,3,3);
   ctx.fillRect(b.x+7,wy+1,3,3);ctx.fillRect(b.x+b.w-13,wy+1,3,3)
  }
  if(b.balc){ctx.fillStyle='#5d4037';ctx.fillRect(b.side?b.x+2:b.x+b.w-10,b.y+25,8,5);ctx.fillStyle='rgba(0,0,0,.2)';ctx.fillRect(b.side?b.x+2:b.x+b.w-10,b.y+25,8,2)}
  const dx=b.side?b.x+4:b.x+b.w-10;
  ctx.fillStyle='#5d4037';ctx.fillRect(dx,b.y+b.h-18,6,18);
  ctx.fillStyle='#795548';ctx.fillRect(dx+1,b.y+b.h-16,2,10);ctx.fillRect(dx+3,b.y+b.h-16,2,10)
 }
 for(let i=0;i<3;i++){
  const ay=(H*.25+i*H*.3)%H;const ax=cv.width/6+Math.sin(Date.now()/1000+1.3+i)*3;
  ctx.fillStyle='#a1887f';ctx.beginPath();ctx.arc(ax,ay,4,0,Math.PI*2);ctx.fill();
  ctx.fillStyle='#fff';ctx.beginPath();ctx.arc(ax-1,ay-1,1.5,0,Math.PI*2);ctx.fill();
  ctx.fillStyle='#5d4037';ctx.beginPath();ctx.arc(ax,ay,4,Math.PI,0);ctx.fill();
  ctx.fillStyle=['#e74c3c','#3498db','#2ecc71'][i];ctx.fillRect(ax-3,ay+4,6,6)
 }
 for(let i=0;i<2;i++){
  const by=(H*.15+i*H*.35)%H;const bx=cv.width*5/6+Math.sin(Date.now()/1000+2.1+i)*3;
  ctx.fillStyle='#a1887f';ctx.beginPath();ctx.arc(bx,by-2,4,Math.PI,0);ctx.fill();
  ctx.fillStyle='#f44336';ctx.beginPath();ctx.arc(bx,by,6,0,Math.PI*2);ctx.fill();
  ctx.fillStyle='#fff';ctx.beginPath();ctx.arc(bx-2,by-1,2,0,Math.PI*2);ctx.fill()
 }}

function ut(c){
 for(const t of tr){t.y+=sp*.8;if(t.y>H)t.y=-100
  ctx.fillStyle=c.t1;ctx.fillRect(t.x-3,t.y,6,25);
  const trType=t.tran;
  if(trType===0){
   ctx.fillStyle='#5d4037';ctx.beginPath();ctx.arc(t.x,t.y-5,4,0,Math.PI*2);ctx.fill();
   ctx.strokeStyle=c.c1;ctx.lineWidth=2;
   ctx.beginPath();ctx.moveTo(t.x,t.y-5);ctx.lineTo(t.x-14,t.y-25);ctx.stroke();
   ctx.beginPath();ctx.moveTo(t.x,t.y-5);ctx.lineTo(t.x+14,t.y-25);ctx.stroke();
   ctx.beginPath();ctx.moveTo(t.x,t.y-5);ctx.lineTo(t.x,t.y-30);ctx.stroke();
   ctx.fillStyle=c.c1;ctx.beginPath();ctx.arc(t.x-14,t.y-25,7,0,Math.PI*2);ctx.fill();
   ctx.beginPath();ctx.arc(t.x+14,t.y-25,7,0,Math.PI*2);ctx.fill();
   ctx.beginPath();ctx.arc(t.x,t.y-30,8,0,Math.PI*2);ctx.fill()
  }else if(trType===1){
   ctx.fillStyle=c.c2;ctx.beginPath();ctx.moveTo(t.x-12,t.y-5);ctx.lineTo(t.x,t.y-32);ctx.lineTo(t.x+12,t.y-5);ctx.closePath();ctx.fill();
   ctx.beginPath();ctx.moveTo(t.x-10,t.y-15);ctx.lineTo(t.x,t.y-38);ctx.lineTo(t.x+10,t.y-15);ctx.closePath();ctx.fill()
  }else if(trType===2){
   ctx.fillStyle=c.c3;ctx.beginPath();ctx.arc(t.x,t.y-18,14,0,Math.PI*2);ctx.fill();
   ctx.fillStyle='rgba(255,100,100,.2)';ctx.beginPath();ctx.arc(t.x-6,t.y-22,4,0,Math.PI*2);ctx.fill();
   ctx.beginPath();ctx.arc(t.x+5,t.y-14,3,0,Math.PI*2);ctx.fill()
  }else{
   ctx.fillStyle=c.c1;ctx.beginPath();ctx.arc(t.x,t.y-10,10,0,Math.PI*2);ctx.fill();
   ctx.strokeStyle=c.c2;ctx.lineWidth=1.5;
   ctx.beginPath();ctx.moveTo(t.x,t.y-10);ctx.lineTo(t.x-10,t.y+5);ctx.stroke();
   ctx.beginPath();ctx.moveTo(t.x-3,t.y-8);ctx.lineTo(t.x-8,t.y+3);ctx.stroke();
   ctx.beginPath();ctx.moveTo(t.x+3,t.y-8);ctx.lineTo(t.x+8,t.y+3);ctx.stroke()
  }
 }}

function ur(c){ctx.fillStyle=c.rl;for(const l of rl){l.y+=sp;if(l.y>H)l.y=-l.h;ctx.fillRect(l.x,l.y,l.w,l.h)}}

function dp(){
 const x=player.x,y=player.y;
 ctx.save();
 if(invuln>0&&Math.floor(invuln/5)%2===0){ctx.globalAlpha=.4}
 ctx.fillStyle=motoColor;ctx.beginPath();ctx.roundRect(x-12,y-25,24,40,8);ctx.fill();
 ctx.strokeStyle='rgba(0,0,0,.3)';ctx.lineWidth=2;ctx.beginPath();ctx.roundRect(x-12,y-25,24,40,8);ctx.stroke();
 ctx.strokeStyle='#333';ctx.lineWidth=3;ctx.beginPath();ctx.moveTo(x-16,y-10);ctx.lineTo(x-24,y-5);ctx.stroke();
 ctx.beginPath();ctx.moveTo(x+16,y-10);ctx.lineTo(x+24,y-5);ctx.stroke();
 ctx.fillStyle='#222';ctx.shadowColor='rgba(0,0,0,.3)';ctx.shadowBlur=4;
 ctx.beginPath();ctx.arc(x-10,y+15,6,0,Math.PI*2);ctx.fill();
 ctx.beginPath();ctx.arc(x+10,y+15,6,0,Math.PI*2);ctx.fill();
 ctx.shadowBlur=0;
 ctx.fillStyle='#FFFFCC';ctx.shadowColor=motoColor;ctx.shadowBlur=12;
 ctx.beginPath();ctx.arc(x,y-24,5,0,Math.PI*2);ctx.fill();
 ctx.shadowBlur=0;
 ctx.restore()
}

function sv2(){
 const t=VT[Math.floor(Math.random()*VT.length)];
 let w,h;
 if(t==='truck'){w=60;h=80}
 else if(t==='bus'){w=70;h=90}
 else if(t==='person'){w=18;h=28}
 else if(t==='animal'){w=25;h=20}
 else if(t==='bicycle'){w=20;h=30}
 else if(t==='triangle'){w=50;h=55}
 else if(t==='square'){w=50;h=50}
 else if(t==='circle'){w=48;h=48}
 else{w=45;h=55}
 const c=VC[Math.floor(Math.random()*VC.length)];
 const roadW=cv.width*2/3-40,minX=cv.width/6+20,maxX=cv.width*5/6-20-roadW;
 veh.push({x:minX+Math.random()*(maxX-minX+roadW),y:-h,w,h,type:t,color:c,passed:false})
}

function dv(v){
 ctx.fillStyle=v.color;ctx.beginPath();ctx.roundRect(v.x-v.w/2,v.y,v.w,v.h,6);ctx.fill();
 ctx.strokeStyle='rgba(0,0,0,.2)';ctx.lineWidth=1;ctx.beginPath();ctx.roundRect(v.x-v.w/2,v.y,v.w,v.h,6);ctx.stroke();
 if(v.type==='car'){
  ctx.fillStyle='rgba(0,0,0,.2)';ctx.beginPath();ctx.roundRect(v.x-v.w/2+5,v.y+5,v.w-10,20,5);ctx.fill();
  ctx.fillStyle='#a0d2ff';ctx.beginPath();ctx.roundRect(v.x-v.w/2+8,v.y+8,v.w-16,10,3);ctx.fill();
  ctx.fillStyle='#333';ctx.beginPath();ctx.arc(v.x-v.w/2+10,v.y+v.h-5,6,0,Math.PI*2);ctx.fill();
  ctx.beginPath();ctx.arc(v.x+v.w/2-10,v.y+v.h-5,6,0,Math.PI*2);ctx.fill()
 }else if(v.type==='truck'){
  ctx.fillStyle='rgba(0,0,0,.2)';ctx.beginPath();ctx.roundRect(v.x-v.w/2+5,v.y+5,25,20,5);ctx.fill();
  ctx.fillStyle='#a0d2ff';ctx.beginPath();ctx.roundRect(v.x-v.w/2+8,v.y+8,15,8,2);ctx.fill();
  ctx.fillStyle='#333';ctx.beginPath();ctx.arc(v.x-v.w/2+8,v.y+v.h-6,7,0,Math.PI*2);ctx.fill();
  ctx.beginPath();ctx.arc(v.x-v.w/2+22,v.y+v.h-6,7,0,Math.PI*2);ctx.fill();
  ctx.beginPath();ctx.arc(v.x+v.w/2-15,v.y+v.h-6,7,0,Math.PI*2);ctx.fill()
 }else if(v.type==='bus'){
  ctx.fillStyle='#a0d2ff';for(let j=0;j<3;j++){ctx.beginPath();ctx.roundRect(v.x-v.w/2+12+j*18,v.y+8,12,10,2);ctx.fill()}
  ctx.fillStyle='#333';ctx.beginPath();ctx.arc(v.x-v.w/2+12,v.y+v.h-6,7,0,Math.PI*2);ctx.fill();
  ctx.beginPath();ctx.arc(v.x+v.w/2-12,v.y+v.h-6,7,0,Math.PI*2);ctx.fill()
 }else if(v.type==='van'){
  ctx.fillStyle='rgba(0,0,0,.15)';ctx.beginPath();ctx.roundRect(v.x-v.w/2+4,v.y+5,v.w-8,20,4);ctx.fill();
  ctx.fillStyle='#a0d2ff';ctx.beginPath();ctx.roundRect(v.x-v.w/2+8,v.y+10,10,8,2);ctx.fill();
  ctx.beginPath();ctx.roundRect(v.x+v.w/2-18,v.y+10,10,8,2);ctx.fill();
  ctx.fillStyle='#333';ctx.beginPath();ctx.arc(v.x-v.w/2+12,v.y+v.h-5,6,0,Math.PI*2);ctx.fill();
  ctx.beginPath();ctx.arc(v.x+v.w/2-12,v.y+v.h-5,6,0,Math.PI*2);ctx.fill()
 }else if(v.type==='person'){
  ctx.fillStyle='#FFD0A0';ctx.beginPath();ctx.arc(v.x,v.y+5,7,0,Math.PI*2);ctx.fill();
  ctx.strokeStyle=v.color;ctx.lineWidth=3;
  ctx.beginPath();ctx.moveTo(v.x,v.y+12);ctx.lineTo(v.x,v.y+v.h-8);ctx.stroke();
  ctx.beginPath();ctx.moveTo(v.x-6,v.y+16);ctx.lineTo(v.x+6,v.y+20);ctx.stroke();
  ctx.beginPath();ctx.moveTo(v.x,v.y+v.h-8);ctx.lineTo(v.x-5,v.y+v.h);ctx.stroke();
  ctx.beginPath();ctx.moveTo(v.x,v.y+v.h-8);ctx.lineTo(v.x+5,v.y+v.h);ctx.stroke();
  ctx.fillStyle=v.color;ctx.fillRect(v.x-6,v.y+15,12,4);
 }else if(v.type==='animal'){
  ctx.fillStyle=v.color;ctx.beginPath();ctx.ellipse(v.x,v.y+v.h/2,v.w/2,v.h/2,0,0,Math.PI*2);ctx.fill();
  ctx.beginPath();ctx.arc(v.x-6,v.y+3,5,0,Math.PI*2);ctx.fill();
  ctx.fillStyle='#333';ctx.beginPath();ctx.arc(v.x-8,v.y+1,2,0,Math.PI*2);ctx.fill();
  ctx.fillStyle='#fff';ctx.beginPath();ctx.arc(v.x-8,v.y+1,1,0,Math.PI*2);ctx.fill();
  ctx.fillStyle='#222';ctx.beginPath();ctx.roundRect(v.x-6,v.y+v.h-4,4,4,2);ctx.fill();
  ctx.beginPath();ctx.roundRect(v.x+2,v.y+v.h-4,4,4,2);ctx.fill();
  ctx.fillStyle='#444';ctx.beginPath();ctx.roundRect(v.x-9,v.y-2,6,3,1);ctx.fill();
  ctx.beginPath();ctx.roundRect(v.x-5,v.y-3,6,3,1);ctx.fill()
 }else if(v.type==='bicycle'){
  ctx.strokeStyle=v.color;ctx.lineWidth=3;
  ctx.beginPath();ctx.arc(v.x-6,v.y+v.h-10,8,0,Math.PI*2);ctx.stroke();
  ctx.beginPath();ctx.arc(v.x+8,v.y+v.h-10,8,0,Math.PI*2);ctx.stroke();
  ctx.beginPath();ctx.moveTo(v.x-6,v.y+v.h-10);ctx.lineTo(v.x+1,v.y+6);ctx.stroke();
  ctx.beginPath();ctx.moveTo(v.x+8,v.y+v.h-10);ctx.lineTo(v.x+1,v.y+6);ctx.stroke();
  ctx.beginPath();ctx.moveTo(v.x-3,v.y+2);ctx.lineTo(v.x+3,v.y+2);ctx.stroke();
  ctx.beginPath();ctx.moveTo(v.x+1,v.y+6);ctx.lineTo(v.x+1,v.y+2);ctx.stroke();
  ctx.fillStyle='#FFD0A0';ctx.beginPath();ctx.arc(v.x-2,v.y-2,4,0,Math.PI*2);ctx.fill()
 }
 else if(v.type==='triangle'){
  ctx.fillStyle=v.color;ctx.shadowColor=v.color;ctx.shadowBlur=15;
  ctx.beginPath();ctx.moveTo(v.x,v.y+4);ctx.lineTo(v.x-v.w/2+6,v.y+v.h-4);ctx.lineTo(v.x+v.w/2-6,v.y+v.h-4);ctx.closePath();ctx.fill();
  ctx.shadowBlur=0
 }
 else if(v.type==='square'){
  ctx.fillStyle=v.color;ctx.shadowColor=v.color;ctx.shadowBlur=12;
  ctx.fillRect(v.x-v.w/2+6,v.y+6,v.w-12,v.h-12);
  ctx.shadowBlur=0
 }
 else if(v.type==='circle'){
  ctx.fillStyle=v.color;ctx.shadowColor=v.color;ctx.shadowBlur=20;
  ctx.beginPath();ctx.arc(v.x,v.y+v.h/2,Math.min(v.w,v.h)/2-6,0,Math.PI*2);ctx.fill();
  ctx.shadowBlur=0
 }
}

function spawnHeart(){
 if(hearts.length>=2)return;
 const roadW=cv.width*2/3-40,minX=cv.width/6+20,maxX=cv.width*5/6-20-roadW;
 hearts.push({x:minX+Math.random()*(maxX-minX+roadW),y:-30,w:20,h:20,active:true})
}
function spawnStar(){
 if(stars.length>=1)return;
 const roadW=cv.width*2/3-40,minX=cv.width/6+20,maxX=cv.width*5/6-20-roadW;
 stars.push({x:minX+Math.random()*(maxX-minX+roadW),y:-30,w:24,h:24,active:true})
}
function us(){
 for(let i=stars.length-1;i>=0;i--){
  const s=stars[i];s.y+=sp;
  ctx.fillStyle='#FFD700';ctx.strokeStyle='#FFA500';ctx.shadowColor='#FFD700';ctx.shadowBlur=35;
  const sx=s.x,sy=s.y+2,sz=24;
  ctx.beginPath();
  for(let i=0;i<5;i++){const a=Math.PI/2*3+i*Math.PI*2/5;ctx.lineTo(sx+Math.cos(a)*sz,sy+Math.sin(a)*sz);const a2=a+Math.PI/5;ctx.lineTo(sx+Math.cos(a2)*sz*.45,sy+Math.sin(a2)*sz*.45)}
  ctx.closePath();ctx.fill()
  ctx.shadowBlur=0;
  if(s.y>H+30)stars.splice(i,1);
  if(s.active&&player.x-player.w/2<s.x+26&&player.x+player.w/2>s.x-26&&player.y-player.h<s.y+26&&player.y>s.y-26){
   s.active=false;stars.splice(i,1);
   playStar();pp(s.x,s.y,'★ NIVEL +1');
   lu();return
  }
 }
}

function uh(){
 for(let i=hearts.length-1;i>=0;i--){
  const h=hearts[i];h.y+=sp;
  ctx.fillStyle='#ff2222';ctx.strokeStyle='#ff6666';ctx.shadowColor='#ff0000';ctx.shadowBlur=30;
  const hx=h.x,hy=h.y+2,s=28;
  ctx.beginPath();ctx.moveTo(hx,hy+s*.35);
  ctx.bezierCurveTo(hx,hy,hx-s*.5,hy,hx-s*.5,hy+s*.35);
  ctx.bezierCurveTo(hx-s*.5,hy+s*.75,hx,hy+s,hx,hy+s);
  ctx.bezierCurveTo(hx,hy+s,hx+s*.5,hy+s*.75,hx+s*.5,hy+s*.35);
  ctx.bezierCurveTo(hx+s*.5,hy,hx,hy,hx,hy+s*.35);
  ctx.closePath();ctx.fill()
  ctx.shadowBlur=0;
  if(h.y>H+30)hearts.splice(i,1);
  if(h.active&&player.x-player.w/2<h.x+22&&player.x+player.w/2>h.x-22&&player.y-player.h<h.y+22&&player.y>h.y-22){
   h.active=false;hearts.splice(i,1);
   if(lives<3){lives++;upHearts();flashHeart(lives);playHeart();pp(h.x,h.y,'+1 ❤')}
  }
 }
}

function uv(){
 for(let i=veh.length-1;i>=0;i--){
  const v=veh[i];v.y+=sp;dv(v);
  if(!v.passed&&v.y>player.y){v.passed=true;vp++;sc+=10;ui();playScore();pp(v.x,v.y,'+10')}
  if(cl(player,v)){hit()}
  if(v.y>H+v.h)veh.splice(i,1)
 }
}

function cl(pl,vr){return pl.x-pl.w/2<vr.x+vr.w/2&&pl.x+pl.w/2>vr.x-vr.w/2&&pl.y-pl.h<vr.y+vr.h&&pl.y>vr.y}

function pp(x,y,t){const e=document.createElement('div');e.className='score-popup';e.textContent=t;e.style.left=(x-15)+'px';e.style.top=y+'px';D('game-container').appendChild(e);setTimeout(()=>{if(e.parentNode)e.remove()},800)}
function cf(){const clr=['#ffdd00','#ff6b00','#00d4ff','#ff4444','#00ff88','#ff00ff','#ff69b4','#fff'],ct=D('game-container');for(let i=0;i<100;i++){const c=document.createElement('div');c.className='confetti';c.style.top='-10px';c.style.left=Math.random()*100+'%';c.style.background=clr[Math.floor(Math.random()*clr.length)];c.style.width=(3+Math.random()*10)+'px';c.style.height=(3+Math.random()*10)+'px';c.style.borderRadius=Math.random()>.5?'50%':'0';c.style.animationDuration=(1.2+Math.random()*.8)+'s';c.style.animationDelay=Math.random()*.3+'s';ct.appendChild(c);setTimeout(()=>{if(c.parentNode)c.remove()},2000)}}

async function lb(){
 D('leaderboard-modal').classList.add('active');D('lb-list').innerHTML='<div class="lb-loading"><i class="fas fa-spinner fa-spin"></i> Cargando...</div>'
 try{const r=await fetch(API+'?action=leaderboard');const d=await r.json();
 if(!d.ok||!d.leaders.length){D('lb-list').innerHTML='<div class="lb-empty">Aun no hay puntajes. Se el primero!</div>';return}
 let h='';d.leaders.forEach((l,i)=>{const cls=i===0?'gold':i===1?'silver':i===2?'bronze':'';const rc=i===0?'top1':i===1?'top2':i===2?'top3':'';const me=l.nickname===nick?' lb-me':'';h+='<div class="lb-row '+cls+'"><div class="lb-rank '+rc+'">'+(i+1)+'</div><div class="lb-name'+me+'">'+esc(l.nickname)+'</div><div class="lb-score">'+l.best_score+'</div></div>'});D('lb-list').innerHTML=h}
 catch(e){D('lb-list').innerHTML='<div class="lb-empty">Error al cargar</div>'}}
function esc(s){const d=document.createElement('div');d.textContent=s;return d.innerHTML}
function drawBg(){if(!ctx)return;ctx.fillStyle='#0d1b3e';ctx.fillRect(0,0,cv.width,cv.height);ctx.fillStyle='#2c3e50';ctx.fillRect(cv.width/6,0,cv.width*2/3,cv.height);ctx.fillStyle='rgba(255,255,255,.1)';for(let i=0;i<12;i++){ctx.fillRect(cv.width/2-80,i*60,4,20);ctx.fillRect(cv.width/2,i*60,4,20);ctx.fillRect(cv.width/2+80,i*60,4,20)}}
if(!CanvasRenderingContext2D.prototype.roundRect){CanvasRenderingContext2D.prototype.roundRect=function(x,y,w,h,r){if(w<2*r)r=w/2;if(h<2*r)r=h/2;this.moveTo(x+r,y);this.arcTo(x+w,y,x+w,y+h,r);this.arcTo(x+w,y+h,x,y+h,r);this.arcTo(x,y+h,x,y,r);this.arcTo(x,y,x+w,y,r);this.closePath();return this}}
async function loadTop3(){
 const el=D('top3-scores');if(!el)return;
 try{
  const r=await fetch(API+'?action=leaderboard');const d=await r.json();
  if(!d.ok||!d.leaders||!d.leaders.length){el.innerHTML='<div class="top3-empty">Aun no hay puntajes</div>';return}
  const top=d.leaders.slice(0,3);const medals=['gold','silver','bronze'];
  let h='<div class="top3-title">🏆 Mejores Puntajes</div>';
  top.forEach((l,i)=>{
   h+='<div class="top3-row '+medals[i]+'"><div class="top3-rank '+medals[i]+'">'+(i+1)+'</div><div class="top3-name">'+esc(l.nickname)+'</div><div class="top3-score">'+l.best_score+'</div></div>'
  });el.innerHTML=h
 }catch(e){el.innerHTML='<div class="top3-empty">--</div>'}
}
async function autoLogin(){
 const device=/Android|iPhone|iPad|iPod/i.test(navigator.userAgent)?'M':'P';
 const id=Math.random().toString(36).substring(2,7).toUpperCase();
 nick='Guest'+device+id;
 try{
  const fd=new FormData();fd.append('nickname',nick);fd.append('device',device=='M'?'Mobile':'PC');fd.append('user_agent',navigator.userAgent || '');
  const r=await fetch(API+'?action=login',{method:'POST',body:fd});const d=await r.json();
  if(d.ok){pid=d.player_id;nick=d.nickname;const m=D('my-nick');if(m)m.textContent='Tu nick: '+nick;const pn=D('player-nick');if(pn)pn.textContent=nick}
 }catch(e){}
}
window.onload=function(){init();autoLogin().then(loadTop3)};
''';

  @override
  void dispose() {
    _webViewController?.dispose();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
}
