#!/bin/bash

#####==========================================================
# スクリプト内で使用する変数を定義
# rpm更新前リストのファイル名 (例: rpm_before_list.20250730)
RPM_BEFORE_LIST="rpm_before_list.$(date +%Y%m%d)"
# rpm更新後リストのファイル名 (例: rpm_after_list.20250730)
RPM_AFTER_LIST="rpm_after_list.$(date +%Y%m%d)"
# メール通知内容を格納するファイルパス (例: /home/ops/tmp/rpm_diff_list.20250730)
RPM_DIFF_LIST="/home/ops/tmp/rpm_diff_list.$(date +%Y%m%d)"
# メール送信先（匿名化）
MAIL_RECIPIENT="admin@example.com"
#####==========================================================

# 作業ディレクトリの準備
if [ ! -d "/home/ops/tmp/" ]; then
    echo "INFO: /home/ops/tmp/ ディレクトリを作成します。"
    mkdir -p "/home/ops/tmp/" || { echo "ERROR: ディレクトリ作成に失敗しました: /home/ops/tmp/"; exit 1; }
fi
cd "/home/ops/tmp/" || { echo "ERROR: ディレクトリへの移動に失敗しました: /home/ops/tmp/"; exit 1; }
echo "INFO: 作業ディレクトリ: $(pwd)"

# 過去のrpmログファイルを30日以上経過したものを削除
echo "INFO: 30日以上前のrpmログファイルを削除します。"
find . -name "rpm_*_list.????????*" -type f -mtime +30 -delete

# メール通知ファイルの初期化
echo "$(date +%Y/%m/%d) のRPM更新結果は以下の通りです。" > "$RPM_DIFF_LIST"
echo -e "\n" >> "$RPM_DIFF_LIST"

# RPM更新前のパッケージリスト取得
echo "INFO: RPM更新前のパッケージリストを取得します: $RPM_BEFORE_LIST"
rpm -qa | sort -n > "$RPM_BEFORE_LIST" || { echo "ERROR: RPM更新前リスト取得失敗。"; exit 1; }

# dnf キャッシュクリア
echo "INFO: dnfキャッシュをクリーンアップします。"
dnf clean all || echo "WARNING: dnf clean all に失敗しましたが継続します。"

# RPM パッケージ更新
echo "INFO: RPM パッケージ更新を開始します。"
dnf -y update
DNF_UPDATE_STATUS=$?

if [ $DNF_UPDATE_STATUS -ne 0 ]; then
    echo "ERROR: dnf update に失敗しました。"
    echo '「dnf updateに失敗しました」' >> "$RPM_DIFF_LIST"
    mail -s "RPM更新失敗通知 「$(hostname -f)」" "$MAIL_RECIPIENT" < "$RPM_DIFF_LIST"
    exit 1
fi

echo "INFO: RPM パッケージ更新が完了しました。"

# RPM更新後リスト取得
echo "INFO: RPM更新後のパッケージリストを取得します: $RPM_AFTER_LIST"
rpm -qa | sort -n > "$RPM_AFTER_LIST" || { echo "ERROR: RPM更新後リスト取得失敗。"; exit 1; }

# ファイル存在確認
if [ ! -e "$RPM_BEFORE_LIST" ] || [ ! -e "$RPM_AFTER_LIST" ] || [ ! -e "$RPM_DIFF_LIST" ]; then
    echo "ERROR: 必要な更新結果ファイルが存在しません。"
    echo "$(date +%Y/%m/%d) のRPM更新結果" > "$RPM_DIFF_LIST"
    echo '「更新結果ファイルが存在しません」' >> "$RPM_DIFF_LIST"
    mail -s "RPM更新ファイル作成エラー 「$(hostname -f)」" "$MAIL_RECIPIENT" < "$RPM_DIFF_LIST"
    exit 1
fi

echo "INFO: 更新結果ファイルの存在を確認しました。"

# 差分チェック
echo "INFO: RPM更新前後のパッケージリストを比較します。"
diff -u "$RPM_BEFORE_LIST" "$RPM_AFTER_LIST" > /dev/null
DIFF_STATUS=$?

if [ $DIFF_STATUS -eq 0 ]; then
    echo "INFO: RPM更新なし。"
    echo '「RPMの更新結果はありません」' >> "$RPM_DIFF_LIST"
    mail -s "RPM更新結果なし 「$(hostname -f)」" "$MAIL_RECIPIENT" < "$RPM_DIFF_LIST"
    exit 0

elif [ $DIFF_STATUS -eq 1 ]; then
    echo "INFO: RPM更新あり。サービス停止: $STOP_ADM_SCRIPT"

    echo "--- RPM 更新詳細 ---" >> "$RPM_DIFF_LIST"
    diff -u "$RPM_BEFORE_LIST" "$RPM_AFTER_LIST" >> "$RPM_DIFF_LIST"

else
    echo "ERROR: diff 実行中にエラー。"
    echo '「RPMリスト比較中にエラーが発生しました」' >> "$RPM_DIFF_LIST"
    mail -s "RPM比較エラー 「$(hostname -f)」" "$MAIL_RECIPIENT" < "$RPM_DIFF_LIST"
    exit 1
fi

# メール送信
echo "INFO: RPM更新結果をメール送信します: $MAIL_RECIPIENT"
mail -s "RPM更新結果 「$(hostname -f)」" "$MAIL_RECIPIENT" < "$RPM_DIFF_LIST"

# 再起動
echo "INFO: 30秒後にOSを再起動します。"
sleep 30
/usr/sbin/reboot || { echo "ERROR: OSの再起動に失敗しました。"; exit 1; }
