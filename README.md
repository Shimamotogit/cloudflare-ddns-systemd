# cloudflare-ddns-systemd

Ubuntu 22.04+ 向けの軽量 Cloudflare IPv4 DDNS。常駐プロセスを使わず、`systemd timer` が既定5分ごとに公開IPv4を確認します。IPが変わらない限り Cloudflare DNS API は呼ばず、1日1回だけ実レコードを照合します。

## Setup

1. Cloudflareで対象Zoneだけに限定した **Zone / DNS / Edit** API Tokenを作成。
2. インストール:
   ```bash
   sudo ./install.sh
   ```
3. `/etc/cloudflare-ddns/config` の `ZONE_ID` / `RECORD_ID` / `RECORD_NAME` を設定。
4. Tokenを `/etc/cloudflare-ddns/token` に保存（`root:root 0600`）。
5. 確認して有効化:
   ```bash
   sudo /usr/local/bin/cloudflare-ddns --check-config
   sudo /usr/local/bin/cloudflare-ddns --dry-run
   sudo systemctl enable --now cloudflare-ddns.timer
   ```

ログ:
```bash
journalctl -u cloudflare-ddns.service
systemctl list-timers cloudflare-ddns.timer
```

## Safety

- 非root専用ユーザー + systemd sandbox
- Tokenは `LoadCredential=` で受け渡し、argv/環境変数へ載せない
- 公開IPv4の妥当性確認に失敗したらDNSを変更しない
- `flock` で多重実行を禁止
- Cloudflare APIはローカルで最短60秒間隔に制限
- timeout / retry回数を上限付きに固定
- 更新前に Record ID / name / type=A を再確認
- `PATCH` は `content` のみ変更し、TTL / Proxy設定を維持
- API成功確認後だけローカル状態を更新

CGNAT環境ではDDNSだけで外部から到達できない場合があります。

## Uninstall

```bash
sudo ./uninstall.sh
# 設定・Token・状態も削除
sudo ./uninstall.sh --purge
```

## License

MIT
