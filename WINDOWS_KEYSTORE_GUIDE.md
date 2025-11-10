# Windows版 キーストア生成ガイド

このガイドは、Windows環境でAndroidリリース用のキーストアファイルを生成する方法を説明します。

## 問題: keytoolコマンドが見つからない

Windows環境で以下のようなエラーが表示される場合：

```
'keytool' は、内部コマンドまたは外部コマンド、
操作可能なプログラムまたはバッチ ファイルとして認識されていません。
```

これは`keytool`コマンドがシステムのPATHに含まれていないためです。

## 解決方法

### 方法1: 自動スクリプトを使用（最も簡単）

プロジェクトルートに用意されている自動スクリプトを使用してください。

#### バッチファイルを使用（推奨）

1. エクスプローラーでプロジェクトフォルダを開く
2. `generate-keystore.bat`ファイルをダブルクリック
3. 画面の指示に従ってパスワードと情報を入力

#### PowerShellスクリプトを使用

1. プロジェクトフォルダで右クリック → "PowerShellウィンドウをここで開く"
2. 以下のコマンドを実行：
   ```powershell
   .\generate-keystore.ps1
   ```
3. 画面の指示に従ってパスワードと情報を入力

### 方法2: Android Studio付属のkeytoolを直接使用

Android Studioがインストールされている場合、以下のコマンドでkeytoolを直接使用できます：

```bash
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### 方法3: JDKをインストール

`keytool`を常にPATHで使用できるようにしたい場合、JDKをインストールしてください。

#### OpenJDKのインストール（推奨）

1. https://adoptium.net/ にアクセス
2. "Latest LTS Release"をダウンロード
3. インストーラーを実行
4. **重要**: インストール時に「Set JAVA_HOME variable」と「Add to PATH」にチェックを入れる
5. インストール後、新しいコマンドプロンプトを開く
6. 以下のコマンドで確認：
   ```bash
   keytool -version
   ```

#### Oracle JDKのインストール

1. https://www.oracle.com/java/technologies/downloads/ にアクセス
2. 最新のJDKをダウンロード
3. インストーラーを実行
4. 環境変数を手動で設定（必要に応じて）

## keytoolのパスを確認する方法

現在のシステムにインストールされているJavaとkeytoolのパスを確認：

```bash
flutter doctor -v
```

出力例：
```
[√] Android toolchain - develop for Android devices
    • Android SDK at C:\Users\...\AppData\Local\Android\sdk
    • Java binary at: C:\Program Files\Android\Android Studio\jbr\bin\java
```

このパスの`java`を`keytool.exe`に置き換えると、keytoolのフルパスになります：
```
C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe
```

## キーストア生成後の手順

1. **`android/key.properties`ファイルを編集**
   ```properties
   storePassword=<設定したパスワード>
   keyPassword=<設定したパスワード>
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```

2. **パスワードを安全な場所に記録**
   - パスワードマネージャーに保存
   - 紙に書いて金庫に保管
   - **絶対に紛失しないこと！**

3. **キーストアファイルをバックアップ**
   - `upload-keystore.jks`を複数の場所にコピー
   - クラウドストレージ（暗号化推奨）
   - 外付けHDD/USBメモリ

4. **リリースビルド**
   ```bash
   flutter build apk --release
   ```
   または
   ```bash
   flutter build appbundle --release
   ```

## トラブルシューティング

### スクリプト実行時に「スクリプトの実行が無効になっています」エラー（PowerShell）

PowerShellのスクリプト実行ポリシーを変更する必要があります：

1. 管理者としてPowerShellを開く
2. 以下のコマンドを実行：
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
3. 「Y」を入力して確定

### Android Studioのパスが異なる

デフォルトのパスにAndroid Studioがインストールされていない場合、スクリプトを編集してパスを修正してください：

**`generate-keystore.bat`の場合:**
```batch
set KEYTOOL="あなたのAndroid Studioのパス\jbr\bin\keytool.exe"
```

**`generate-keystore.ps1`の場合:**
```powershell
$keytoolPath = "あなたのAndroid Studioのパス\jbr\bin\keytool.exe"
```

## 参考情報

詳細なビルド手順については`ANDROID_RELEASE_BUILD.md`を参照してください。
