import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../domain/theme_models.dart';

class LineStoreClient {
  LineStoreClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ThemeBundleInfo> inspectStoreUrl(String storeUrl) async {
    final uri = Uri.tryParse(storeUrl);
    if (uri == null || !uri.hasScheme) {
      throw const FormatException('LINE Theme URL 格式不正確。');
    }

    final response = await _client.get(
      uri,
      headers: const <String, String>{
        'content-type': 'text/html; charset=UTF-8',
        'user-agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
      },
    );

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('讀取 LINE Store 頁面失敗，HTTP ${response.statusCode}');
    }

    final document = html_parser.parse(response.body);
    final coverUrl = _extractCoverUrl(document.outerHtml);
    if (coverUrl == null) {
      throw const FormatException('找不到主題封面圖，無法推算版本號。');
    }

    final normalizedCoverUrl = coverUrl.startsWith('//')
        ? 'https:$coverUrl'
        : coverUrl;
    final coverUri = Uri.parse(normalizedCoverUrl);
    final segments = coverUri.pathSegments;
    final productsIndex = segments.indexOf('products');

    if (productsIndex < 0 || segments.length <= productsIndex + 5) {
      throw const FormatException('封面圖 URL 格式不符合預期，無法解析 theme id / version。');
    }

    final themeId = segments[productsIndex + 4];
    final version = int.tryParse(segments[productsIndex + 5]);
    if (themeId.length < 6 || version == null) {
      throw const FormatException('封面圖 URL 缺少正確的主題版本資訊。');
    }

    final downloadUrl = Uri.parse(
      'https://shop.line-scdn.net/themeshop/v1/products/'
      '${themeId.substring(0, 2)}/${themeId.substring(2, 4)}/${themeId.substring(4, 6)}/'
      '$themeId/$version/ANDROID/theme.zip',
    );

    return ThemeBundleInfo(
      coverUrl: normalizedCoverUrl,
      themeId: themeId,
      version: version,
      downloadUrl: downloadUrl,
    );
  }

  Future<List<int>> downloadThemeBundle(Uri downloadUrl) async {
    final sourceResponse = await _client.get(downloadUrl);
    if (sourceResponse.statusCode != HttpStatus.ok) {
      throw HttpException('下載官方主題失敗，HTTP ${sourceResponse.statusCode}');
    }

    return sourceResponse.bodyBytes;
  }

  void dispose() {
    _client.close();
  }

  String? _extractCoverUrl(String htmlSource) {
    final match = RegExp(
      r'''(https?:)?//shop\.line-scdn\.net/themeshop/v1/products/[^"']+/icon_198x278\.png''',
      caseSensitive: false,
    ).firstMatch(htmlSource);

    return match?.group(0);
  }
}
