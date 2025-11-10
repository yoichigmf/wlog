# Androidリリース版ビルドガイド

このガイドでは、Androidのリリース版（APKまたはAAB）をビルドする手順を説明します。

## 前提条件

- Flutter SDKがインストールされていること
- Android SDKがインストールされていること
- JDK（Java Development Kit）がインストールされていること

## ステップ1: キーストアファイルの作成（初回のみ）

リリース版のAPKに署名するためのキーストアファイルを作成します。

### Windows版（簡単な方法）

プロジェクトルートに用意されたスクリプトを使用してください：

**バッチファイル（推奨）:**
```
generate-keystore.bat
```
をダブルクリックして実行

**PowerShellスクリプト:**
```powershell
.\generate-keystore.ps1
```

### 手動でコマンドを実行する場合

Android Studio付属のkeytoolを使用：

```bash
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

または、JDKがインストールされている場合：

```bash
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**コマンドの説明:**
- `upload-keystore.jks`: キーストアファイルの名前
- `10000`: キーの有効期限（日数）= 約27年
- `upload`: キーのエイリアス名

**実行時に入力する情報:**
1. キーストアのパスワード（強力なパスワードを設定し、**必ず記録してください**）
2. 名前、組織、都市、都道府県などの情報
3. 国コード（日本の場合は`JP`）
4. キーのパスワード（通常はキーストアと同じパスワードでOK - Enterキーを押す）

**重要:**
- **キーストアファイルとパスワードは厳重に保管してください**
- これらを紛失すると、アプリの更新版をGoogle Play Storeに公開できなくなります
- バックアップを取ることを強く推奨します

### keytoolが見つからない場合

`keytool`コマンドが認識されない場合、以下を確認してください：

1. **Android Studioがインストールされているか**
   - Android Studioには`keytool`が含まれています
   - パス: `C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`

2. **JDKがインストールされているか**
   - Oracle JDK: https://www.oracle.com/java/technologies/downloads/
   - OpenJDK: https://adoptium.net/ (推奨)

3. **Flutter Doctorで確認**
   ```bash
   flutter doctor -v
   ```
   このコマンドでJavaのパスが表示されます

## ステップ2: キー設定ファイルの作成

プロジェクトルートに作成されたキーストアファイルを確認し、`android/key.properties`ファイルを編集します。

**`android/key.properties`の内容:**
```properties
storePassword=<ステップ1で設定したキーストアのパスワード>
keyPassword=<ステップ1で設定したキーのパスワード>
keyAlias=upload
storeFile=../upload-keystore.jks
```

**例:**
```properties
storePassword=MySecurePassword123
keyPassword=MySecurePassword123
keyAlias=upload
storeFile=../upload-keystore.jks
```

**注意:** このファイルは`.gitignore`に追加されているため、Gitにコミットされません。

## ステップ3: ビルド設定の確認

`android/app/build.gradle.kts`に署名設定が追加されていることを確認してください（既に設定済み）。

## ステップ4: リリース版のビルド

### 方法A: APK（Android Package）のビルド

APKは直接インストールできるファイル形式です。

```bash
flutter build apk --release
```

**ビルドされたファイルの場所:**
```
build/app/outputs/flutter-apk/app-release.apk
```

### 方法B: App Bundle（AAB）のビルド（Google Play Store推奨）

App BundleはGoogle Play Store向けの最適化された形式です。

```bash
flutter build appbundle --release
```

**ビルドされたファイルの場所:**
```
build/app/outputs/bundle/release/app-release.aab
```

### ビルドオプション

#### ターゲットプラットフォームの指定（APKのみ）

デフォルトでは、複数のアーキテクチャ用のAPKがビルドされます。特定のアーキテクチャのみをビルドする場合：

```bash
# ARM 64-bit版のみ（最新のAndroid端末）
flutter build apk --release --target-platform android-arm64

# ARM 32-bit版のみ（古いAndroid端末）
flutter build apk --release --target-platform android-arm

# すべてのアーキテクチャを個別のAPKとしてビルド
flutter build apk --release --split-per-abi
```

`--split-per-abi`オプションを使用すると、以下のファイルが生成されます：
- `app-armeabi-v7a-release.apk` (32-bit ARM)
- `app-arm64-v8a-release.apk` (64-bit ARM)
- `app-x86_64-release.apk` (64-bit x86)

#### 難読化（コード保護）

リリース版ではコードの難読化が推奨されます：

```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

- `--obfuscate`: コードを難読化してリバースエンジニアリングを困難にする
- `--split-debug-info`: デバッグ情報を分離（クラッシュレポート解析に使用）

## ステップ5: ビルドの確認

ビルドが成功したら、以下を確認してください：

1. **APKファイルのサイズ**: 適切なサイズか確認
2. **インストールテスト**: 実機でインストールして動作確認

```bash
# APKを接続されたAndroid端末にインストール
flutter install
```

または、ファイルマネージャーでAPKファイルを見つけて、実機にコピーしてインストールします。

## Google Play Storeへの公開

### App Bundle（AAB）をアップロード

1. [Google Play Console](https://play.google.com/console/)にアクセス
2. アプリを作成または選択
3. 「製品版」→「リリース」→「新しいリリースを作成」
4. ビルドした`app-release.aab`をアップロード
5. リリースノートを記入して公開

### 初回公開時の注意

- アプリのスクリーンショット（最低2枚）
- アイコン（512x512 PNG）
- 簡単な説明と詳細な説明
- プライバシーポリシーのURL（必須）
- コンテンツレーティング
- ターゲット年齢層

## トラブルシューティング

### エラー: "Keystore file not found"

`android/key.properties`ファイルの`storeFile`パスが正しいか確認してください。

### エラー: "Keystore was tampered with, or password was incorrect"

`android/key.properties`ファイルのパスワードが正しいか確認してください。

### ビルドサイズが大きい

`--split-per-abi`オプションを使用して、アーキテクチャごとに分割されたAPKをビルドしてください。

### Google Play Storeでの署名

Google Play App Signingを使用している場合、Google Playが最終的な署名を行います。
初回アップロード時にアップロードキーで署名されたAABをアップロードし、その後Google Playが管理します。

## バージョン管理

アプリのバージョンは`pubspec.yaml`で管理されます：

```yaml
version: 1.0.0+1
```

- `1.0.0`: バージョン名（ユーザーに表示される）
- `+1`: バージョンコード（内部管理用の整数）

更新版をリリースする際は、バージョンコードを必ずインクリメントしてください：

```yaml
version: 1.0.1+2
```

## セキュリティのベストプラクティス

1. **キーストアファイルをバックアップ**: 複数の安全な場所に保管
2. **パスワードを記録**: パスワード管理ツールに保存
3. **key.propertiesをGitにコミットしない**: 既に`.gitignore`に追加済み
4. **キーストアを共有しない**: チーム内でも厳重に管理
5. **本番用と開発用で別のキーを使用**: 開発中はデバッグキーを使用

## 参考リンク

- [Flutterアプリの署名（公式ドキュメント）](https://docs.flutter.dev/deployment/android)
- [Google Play Console](https://play.google.com/console/)
- [Android App Bundleについて](https://developer.android.com/guide/app-bundle)
