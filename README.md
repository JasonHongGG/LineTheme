# LINE Theme Tester

這是一個 Android 導向的 Flutter 測試工具

## 功能

- 輸入 LINE Theme Store 網址後，自動抓取封面圖 URL，並從其中解析出正確的 `themeId` 與 `version`

## 權限需求

Samsung A32 這類裝置通常會封鎖一般 app 存取 `Android/data`，因此這個版本改用 Shizuku。

使用前請先：

1. 安裝 Shizuku app
2. 用無線除錯或電腦 adb 啟動 Shizuku
3. 回到 LINE Theme Tester，按「請求 Shizuku 授權」

透過 Shizuku 直接列出 `/storage/emulated/0/Android/data/jp.naver.line.android/files/theme` 

## 開發指令

```bash
flutter pub get
flutter analyze
flutter run
```

