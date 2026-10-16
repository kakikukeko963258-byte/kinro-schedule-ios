# 金ロー予定

公式サイト https://kinro.ntv.co.jp/lineup のHTMLから画像・作品名・放送日時・みどころ・ストーリーを取得する非公式iOSアプリ。iOS 16以降。今週・来週・その先に分類し、詳細画面から公式ページを開けます。下に引いて更新。取得済みのテキストはキャッシュし、通信失敗時にも表示します。画像のオフライン表示は保証しません。

週は日本時間の月曜始まりです。今週分は放送後も日曜まで表示します。未発表の予定は推測せず、未掲載と表示します。サイト構造変更時はパーサーの更新が必要です。一部詳細取得に失敗した場合は他の予定を表示し、公式ページへ案内します。

## IPA

GitHub ActionsのmacOS runner + XcodeでReleaseビルドし、Actions Artifactと公開GitHub Releaseへ `Kinro.ipa` を保存します。Windowsからpushするだけでビルドできます。Apple証明書不要の未署名IPAをAltStoreで再署名してインストールしてください。

Bundle ID: `com.studyquiz.dailyquiz`（StudyQuizと同一）。既存StudyQuizを置き換えます。

## 検証

Actionsで `swift test`、XcodeGen生成、実機向けReleaseビルド、Info.plistのBundle ID確認、IPA ZIP整合性確認を実行します。テスト用HTMLは2026-10-16取得の公式サイト構造のフィクスチャです。アプリの取得データは常に公式サイトへアクセスして更新します。

作品画像・説明の著作権は各権利者に帰属します。公式サービスとは無関係です。
