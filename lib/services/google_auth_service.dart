import 'dart:io' show Platform;
import 'dart:convert' show jsonDecode;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart' as standard;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart' as all_platforms;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;

/// Google認証サービス
class GoogleAuthService {
  /// Google Sign-Inがサポートされているプラットフォームかチェック
  static bool get isSupported => true; // 両パッケージを使用して全プラットフォーム対応

  /// 現在のプラットフォームがWindows/Linuxかどうか
  static bool get _isDesktopUnsupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux;
  }

  // Web用のクライアントID（環境変数から取得）
  // Web版でGoogle Sign-Inを使用する場合は、Google Cloud Consoleで
  // 「ウェブアプリケーション」タイプのOAuthクライアントIDを作成してください
  // 承認済みのJavaScript生成元: http://localhost
  // 承認済みのリダイレクトURI: http://localhost
  // .envファイルにGOOGLE_WEB_CLIENT_IDを設定してください
  static final String _webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

  // Google Sign-Inのインスタンス（標準パッケージ: Android/iOS/macOS/Web）
  static final standard.GoogleSignIn _standardGoogleSignIn = standard.GoogleSignIn(
    clientId: _webClientId,
    scopes: [
      sheets.SheetsApi.spreadsheetsScope,
      drive.DriveApi.driveScope,
    ],
  );

  // Google Sign-Inのインスタンス（全プラットフォーム版: Windows/Linux）
  // デスクトップ版のOAuth 2.0認証情報（環境変数から取得）
  // 設定方法:
  // 1. https://console.cloud.google.com/ でプロジェクトを選択
  // 2. 「API とサービス」→「認証情報」→「認証情報を作成」→「OAuth 2.0 クライアント ID」
  // 3. アプリケーションの種類で「デスクトップアプリ」を選択
  // 4. 作成したクライアントIDとシークレットを.envファイルに設定
  //    GOOGLE_DESKTOP_CLIENT_ID=your-desktop-client-id
  //    GOOGLE_DESKTOP_CLIENT_SECRET=your-desktop-client-secret
  static final String _desktopClientId = dotenv.env['GOOGLE_DESKTOP_CLIENT_ID'] ?? '';
  static final String _desktopClientSecret = dotenv.env['GOOGLE_DESKTOP_CLIENT_SECRET'] ?? '';

  static all_platforms.GoogleSignIn? _allPlatformsGoogleSignIn;

  /// デスクトップ版のGoogleSignInインスタンスを取得（遅延初期化）
  static all_platforms.GoogleSignIn _getAllPlatformsGoogleSignIn() {
    if (_allPlatformsGoogleSignIn != null) {
      return _allPlatformsGoogleSignIn!;
    }

    if (_desktopClientId.isEmpty || _desktopClientSecret.isEmpty) {
      throw Exception(
        'Windows/Linux版でGoogle Sign-Inを使用するには、デスクトップアプリ用のOAuth 2.0認証情報が必要です。\n\n'
        '設定方法:\n'
        '1. https://console.cloud.google.com/ にアクセス\n'
        '2. プロジェクトを選択\n'
        '3. 「API とサービス」→「認証情報」を開く\n'
        '4. 「認証情報を作成」→「OAuth 2.0 クライアント ID」を選択\n'
        '5. アプリケーションの種類で「デスクトップアプリ」を選択\n'
        '6. 作成したクライアントIDとシークレットを.envファイルに設定:\n'
        '   GOOGLE_DESKTOP_CLIENT_ID=your-desktop-client-id\n'
        '   GOOGLE_DESKTOP_CLIENT_SECRET=your-desktop-client-secret\n\n'
        'Android/iOS版では追加設定なしで動作します。'
      );
    }

    _allPlatformsGoogleSignIn = all_platforms.GoogleSignIn(
      params: all_platforms.GoogleSignInParams(
        clientId: _desktopClientId,
        clientSecret: _desktopClientSecret,
        scopes: const [
          'https://www.googleapis.com/auth/userinfo.email',
          'https://www.googleapis.com/auth/userinfo.profile',
          'https://www.googleapis.com/auth/drive',
          'https://www.googleapis.com/auth/spreadsheets',
        ],
      ),
    );

    return _allPlatformsGoogleSignIn!;
  }

  /// 現在サインインしているGoogleアカウントを取得
  static standard.GoogleSignInAccount? get currentUser {
    if (_isDesktopUnsupportedPlatform) {
      return null; // all_platforms版は currentUser を提供しない
    }
    return _standardGoogleSignIn.currentUser;
  }

  /// サインインしているかどうか
  static bool get isSignedIn {
    if (_isDesktopUnsupportedPlatform) {
      // all_platforms版は認証状態を確認する方法が限定的
      // checkDesktopSignInStatus()で非同期確認が必要
      return false; // UIでは非同期メソッドを使用すること
    }
    return _standardGoogleSignIn.currentUser != null;
  }

  /// Windows/Linux版のサインイン状態を確認（非同期）
  /// 実際にAPIにアクセスして認証状態を確認します
  static Future<bool> checkDesktopSignInStatus() async {
    if (!_isDesktopUnsupportedPlatform) {
      return isSignedIn;
    }

    try {
      final desktopSignIn = _getAllPlatformsGoogleSignIn();
      final client = await desktopSignIn.authenticatedClient;
      return client != null;
    } catch (e) {
      print('デスクトップ版サインイン状態確認エラー: $e');
      return false;
    }
  }

  /// ユーザー情報を取得（Windows/Linux版対応）
  /// Windows/Linux版ではGoogle OAuth2 APIを使用してユーザー情報を取得
  static Future<String?> getUserEmail() async {
    print('[getUserEmail] 開始 - プラットフォーム: ${_isDesktopUnsupportedPlatform ? "Desktop" : "Mobile"}');

    if (!_isDesktopUnsupportedPlatform) {
      final email = currentUser?.email;
      print('[getUserEmail] モバイル版のメール: $email');
      return email;
    }

    try {
      print('[getUserEmail] 認証クライアント取得中...');
      // ensureSignedIn()を呼ばずに、既存の認証情報のみを使用
      final desktopSignIn = _getAllPlatformsGoogleSignIn();
      final client = await desktopSignIn.authenticatedClient;

      if (client == null) {
        print('[getUserEmail] 認証クライアントがnull（サインインが必要）');
        return null;
      }
      print('[getUserEmail] 認証クライアント取得成功');

      // Google OAuth2 APIを使用してユーザー情報を取得
      print('[getUserEmail] ユーザー情報API呼び出し中...');
      final response = await client.get(
        Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
      );

      print('[getUserEmail] APIレスポンスコード: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('[getUserEmail] レスポンスボディ: ${response.body}');
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final email = json['email'] as String?;
        print('[getUserEmail] 取得したメール: $email');
        return email;
      }
      print('[getUserEmail] APIレスポンスが200以外');
      return null;
    } catch (e) {
      print('ユーザー情報取得エラー: $e');
      print('エラー詳細: ${e.toString()}');
      return null;
    }
  }

  /// Googleアカウントでサインイン
  static Future<standard.GoogleSignInAccount?> signIn() async {
    try {
      if (_isDesktopUnsupportedPlatform) {
        // Windows/Linux: all_platforms版を使用
        print('[Google Sign-In] Windows/Linux版のサインイン開始');
        final desktopSignIn = _getAllPlatformsGoogleSignIn();
        print('[Google Sign-In] GoogleSignInインスタンス取得完了');
        print('[Google Sign-In] ブラウザを開いてサインイン中...');
        final result = await desktopSignIn.signIn();
        print('[Google Sign-In] サインイン結果: $result');
        return null; // all_platforms版はアカウント情報を返さない
      } else {
        // Android/iOS/macOS/Web: 標準版を使用
        print('[Google Sign-In] モバイル版のサインイン開始');
        final account = await _standardGoogleSignIn.signIn();
        print('[Google Sign-In] サインイン完了: ${account?.email}');
        return account;
      }
    } catch (e) {
      print('Google Sign-In エラー: $e');
      print('エラースタックトレース: ${StackTrace.current}');
      rethrow; // エラーを上位に伝播して、UIでエラーメッセージを表示できるようにする
    }
  }

  /// サインアウト
  static Future<void> signOut() async {
    try {
      if (_isDesktopUnsupportedPlatform) {
        final desktopSignIn = _getAllPlatformsGoogleSignIn();
        await desktopSignIn.signOut();
      } else {
        await _standardGoogleSignIn.signOut();
      }
    } catch (e) {
      print('Google Sign-Out エラー: $e');
    }
  }

  /// サインインしているか確認し、サインインしていない場合はサインインを促す
  static Future<standard.GoogleSignInAccount?> ensureSignedIn() async {
    if (_isDesktopUnsupportedPlatform) {
      await signIn();
      return null;
    }

    if (isSignedIn) {
      return currentUser;
    }
    return await signIn();
  }

  /// 認証済みHTTPクライアントを取得（Google APIs用）
  static Future<auth.AuthClient?> getAuthenticatedClient() async {
    try {
      await ensureSignedIn();

      if (_isDesktopUnsupportedPlatform) {
        // Windows/Linux: all_platforms版の authenticatedClient を使用
        final desktopSignIn = _getAllPlatformsGoogleSignIn();
        final client = await desktopSignIn.authenticatedClient;
        // Client を AuthClient として返す（両方とも http.Client を継承）
        return client as auth.AuthClient?;
      } else {
        // Android/iOS/macOS/Web: 標準版の authenticatedClient を使用
        final authClient = await _standardGoogleSignIn.authenticatedClient();
        return authClient;
      }
    } catch (e) {
      print('認証クライアント取得エラー: $e');
      return null;
    }
  }

  /// Sheets APIインスタンスを取得
  static Future<sheets.SheetsApi?> getSheetsApi() async {
    final client = await getAuthenticatedClient();
    if (client == null) return null;

    return sheets.SheetsApi(client);
  }

  /// Drive APIインスタンスを取得
  static Future<drive.DriveApi?> getDriveApi() async {
    final client = await getAuthenticatedClient();
    if (client == null) return null;

    return drive.DriveApi(client);
  }
}
