## 1. 機能概要
このスクリプトは以下を自動で行います。
定期メンテナンスや夜間の自動パッチ適用に最適ですが、アップデートが完了した場合OSの強制再起動が発生するため、Cron等での実行を推奨します

```
1.作業ディレクトリ（例 /home/ops/tmp）の準備

2.更新前の RPM パッケージリスト取得

3.dnf キャッシュクリア

4.dnf -y update による RPM 更新

5.更新後のパッケージリスト取得

6.前後リストの diff 比較

7.結果をメール送信

8.必要であればサービス停止

9.OS の強制再起動（30秒後）
```

## 2. 必要環境
・OS: RHEL / RockyLinux / AlmaLinux / CentOS Stream

・root 権限（rpm / dnf / reboot のため）

・ローカル MTA（mail コマンドが使えること）

・bash（/bin/bash）

・dnf が使用できる環境


## 3. 設置場所
```
例：
/home/ops/bin/rpm_update.sh

実行権限を付与：

chmod +x /home/ops/bin/rpm_update.sh
```

## 4. 設定項目
スクリプト冒頭の変数を環境に合わせて修正してください。
```
MAIL_RECIPIENT="admin@example.com"

STOP_ADM_SCRIPT="/home/ops/bin/adm/stop_adm"

WORKDIR="/home/ops/tmp/"
```

## 5. 実行方法（cron 設定例）
```
毎週日曜深夜 3:00 に実行する例：

0 3 * * 0 root /home/ops/bin/rpm_update.sh
```
