// ignore_for_file: prefer_collection_literals, avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webview_pro/webview_flutter.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/msg_controller.dart';

class WebviewController extends StatefulWidget {
  const WebviewController({Key? key}) : super(key: key);

  @override
  State<WebviewController> createState() => _WebviewControllerState();
}

class _WebviewControllerState extends State<WebviewController> {
  // URL 초기화
  final String url = "https://bokdaeri.com/";

  final MsgController _msgController = Get.put(MsgController());

  // 인덱스 페이지 초기화
  bool isInMainPage = true;

  // 웹뷰 컨트롤러 초기화
  final Completer<WebViewController> _controller =
  Completer<WebViewController>();

  WebViewController? _viewController;

  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid) WebView.platform = AndroidWebView();
    _requestStoragePermission();
  }

  // 저장매체 접근 권한 요청
  void _requestStoragePermission() async {
    PermissionStatus status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      PermissionStatus result =
      await Permission.manageExternalStorage.request();
      if (!result.isGranted) {
        print('Permission denied by user');
      } else {
        print('Permission has submitted.');
      }
    }
  }

  // 쿠키 획득
  Future<String> _getCookies(WebViewController controller) async {
    final String cookies =
    await controller.runJavascriptReturningResult('document.cookie;');
    return cookies;
  }

  // 쿠키 설정
  Future<void> _setCookies(WebViewController controller, String cookies) async {
    await controller
        .runJavascriptReturningResult('document.cookie="$cookies";');
  }

  // 쿠키 저장
  Future<void> _saveCookies(String cookies) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('cookies', cookies);
  }

  // 쿠키 로드
  Future<String?> _loadCookies() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('cookies');
  }

  JavascriptChannel _flutterWebviewProJavascriptChannel(BuildContext context) {
    return JavascriptChannel(
      name: 'flutter_webview_pro',
      onMessageReceived: (JavascriptMessage message) async {
        Map<String, dynamic> jsonData = jsonDecode(message.message);
        if (jsonData['handler'] == 'webviewJavaScriptHandler') {
          if (jsonData['action'] == 'setUserId') {
            String userId = jsonData['data']['userId'];
            GetStorage().write('userId', userId);

            print('@addJavaScriptHandler userId $userId');

            String? token = await _getPushToken();
            _viewController?.runJavascript('tokenUpdate("$token")');
          }
        }
        setState(() {});
      },
    );
  }

  Future<String?> _getPushToken() async {
    return await _msgController.getToken();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SizedBox(
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            child: WillPopScope(
              onWillPop: () async {
                if (_viewController == null) {
                  return false;
                }

                final currentUrl = await _viewController?.currentUrl();

                if (currentUrl == url) {
                  if (!mounted) return false;
                  return showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text("앱을 종료하시겠습니까?"),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(true);
                              if (kDebugMode) {
                                print("앱이 포그라운드에서 종료되었습니다.");
                              }
                            },
                            child: const Text("확인"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(false);
                              if (kDebugMode) {
                                print("앱이 종료되지 않았습니다.");
                              }
                            },
                            child: const Text("취소"),
                          ),
                        ],
                      );
                    },
                  ).then((value) => value ?? false);
                } else if (await _viewController!.canGoBack() &&
                    _viewController != null) {
                  _viewController!.goBack();
                  if (kDebugMode) {
                    print("이전 페이지로 이동하였습니다.");
                  }
                  isInMainPage = false;
                  return false;
                }
                return false;
              },
              child: SafeArea(
                child: WebView(
                  initialUrl: url,
                  javascriptMode: JavascriptMode.unrestricted,
                  javascriptChannels: <JavascriptChannel>[
                    _flutterWebviewProJavascriptChannel(context),
                  ].toSet(),
                  onWebResourceError: (error) {
                    print("Error Code: ${error.errorCode}");
                    print("Error Description: ${error.description}");
                  },
                  onWebViewCreated:
                      (WebViewController webviewController) async {
                    _controller.complete(webviewController);
                    _viewController = webviewController;

                    webviewController.currentUrl().then((url) {
                      if (url == "$url") {
                        setState(() {
                          isInMainPage = true;
                        });
                      } else {
                        setState(() {
                          isInMainPage = false;
                        });
                      }
                    });
                  },
                  onPageStarted: (String url) async {
                    print("Current Page: $url");
                  },
                  onPageFinished: (String url) async {

                    if (url.contains(url) && _viewController != null) {
                      await _viewController!.runJavascript("""
                        (function() {
                          function scrollToFocusedInput(event) {
                            const focusedElement = document.activeElement;
                            if (focusedElement.tagName.toLowerCase() === 'input' || focusedElement.tagName.toLowerCase() === 'textarea') {
                              setTimeout(() => {
                                focusedElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
                              }, 500);
                            }
                          }
                
                          document.addEventListener('focus', scrollToFocusedInput, true);
                        })();
                      """);
                    }

                    if (url.contains(
                        "${url}login.php") &&
                        _viewController != null) {
                      final cookies = await _getCookies(_viewController!);
                      await _saveCookies(cookies);
                    } else {
                      final cookies = await _loadCookies();

                      if (cookies != null) {
                        await _setCookies(_viewController!, cookies);
                      }
                    }
                  },
                  geolocationEnabled: true,
                  zoomEnabled: false,
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>[
                    Factory<EagerGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                    ),
                  ].toSet(),
                  gestureNavigationEnabled: true, // IOS Only
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}