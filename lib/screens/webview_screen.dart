import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_android/webview_flutter_android.dart'
    as webview_flutter_android;
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:webview_flutter_module/constants/text_constants.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({Key? key}) : super(key: key);

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late WebViewController controller;

  var loadingPercentage = 0;

  int _selectedIndex = 0;

  void _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index; // Update the selected index
    });

    final messenger = ScaffoldMessenger.of(context); // Get the messenger

    if (index == 2) {
      // Handle going forward
      if (await controller.canGoForward()) {
        await controller.goForward();
      } else {
        messenger.showSnackBar(
          const SnackBar(
            duration: Duration(milliseconds: 200),
            content: Text(
              'No forward history item',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } else if (index == 1) {
      // Handle reload
      controller.reload();
    } else if (index == 0) {
      // Handle going back
      if (await controller.canGoBack()) {
        await controller.goBack();
      } else {
        messenger.showSnackBar(
          const SnackBar(
            duration: Duration(milliseconds: 200),
            content: Text(
              'Can\'t go back',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Permission.mediaLibrary.request();
    Permission.phone.request();
    Permission.photos.request();
    Permission.storage.request();
    Permission.camera.request();

    controller = WebViewController()
      ..setNavigationDelegate(NavigationDelegate(onPageStarted: (url) {
        setState(() {
          loadingPercentage = 0;
        });
      }, onProgress: (progress) {
        setState(() {
          loadingPercentage = progress;
        });
      }, onPageFinished: (url) {
        setState(() {
          loadingPercentage = 100;
        });
      },

          // Keeping track of navigation uisng NavigationDelegate
          onNavigationRequest: (navigation) {
        final host = Uri.parse(navigation.url).host;
        if (host.contains('youtube.com')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Blocking navigation to $host',
              ),
            ),
          );
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      }))
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'SnackBar',
        onMessageReceived: (message) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
            message.message,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          )));
        },
      )
      ..loadRequest(
        Uri.parse(TextConstants.successiveWebUrl),
      );

    initFilePicker();
  }

  /// handle attachments
  initFilePicker() async {
    if (Platform.isAndroid) {
      final androidController = (controller.platform
          as webview_flutter_android.AndroidWebViewController);
      await androidController.setOnShowFileSelector(_androidFilePicker);
    }
  }

  Future<List<String>> _androidFilePicker(
      webview_flutter_android.FileSelectorParams params) async {
    if (params.acceptTypes.any((type) => type == 'image/*')) {
      final picker = image_picker.ImagePicker();
      final photo =
          await picker.pickImage(source: image_picker.ImageSource.camera);

      if (photo == null) {
        return [];
      }
      return [Uri.file(photo.path).toString()];
    } else if (params.acceptTypes.any((type) => type == 'video/*')) {
      final picker = image_picker.ImagePicker();
      final vidFile = await picker.pickVideo(
          source: ImageSource.camera, maxDuration: const Duration(seconds: 10));
      if (vidFile == null) {
        return [];
      }
      return [Uri.file(vidFile.path).toString()];
    } else {
      try {
        if (params.mode ==
            webview_flutter_android.FileSelectorMode.openMultiple) {
          final attachments =
              await FilePicker.platform.pickFiles(allowMultiple: true);
          if (attachments == null) return [];

          return attachments.files
              .where((element) => element.path != null)
              .map((e) => File(e.path!).uri.toString())
              .toList();
        } else {
          final attachment = await FilePicker.platform.pickFiles();
          if (attachment == null) return [];
          File file = File(attachment.files.single.path!);
          return [file.uri.toString()];
        }
      } catch (e) {
        return [];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      // appBar: AppBar(
      //     centerTitle: true,
      //     title: const Text(TextConstants.appBarTitle),
      //     actions: [Menu(controller: controller)]),
      body: Stack(
        children: [
          WebViewWidget(
            controller: controller,
          ),
          loadingPercentage < 100
              ? LinearProgressIndicator(
                  color: Colors.red,
                  value: loadingPercentage / 100.0,
                )
              : Container()
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex, // Keep track of the selected index
        onTap: _onItemTapped,
        selectedItemColor: Colors.grey,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.arrow_back_ios),
            label: 'Back',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.replay),
            label: 'Reload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.arrow_forward_ios),
            label: 'Next',
          ),
        ],
      ),
    ));
  }
}
