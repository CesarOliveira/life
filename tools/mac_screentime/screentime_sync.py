#!/usr/bin/env python3
"""Lê o tempo de uso POR APP do banco knowledgeC do macOS e envia para o Life.

ATENÇÃO: no macOS 26 o knowledgeC só contém o uso do PRÓPRIO MAC — o Tempo de Uso
do iPhone NÃO é mais legível aqui (virou E2E no CloudKit). Para o iPhone, use a
ação de Atalhos "Get App & Website Activity" (iOS/macOS 26) -> POST /api/usage.
Este script serve só para registrar o uso do Mac (use DEVICE_FILTER=local e, p.ex.,
DEVICE=mac).

Config por variáveis de ambiente:
  LIFE_ENDPOINT  ex.: https://life.cesaroliveira.online/api/usage
  LIFE_TOKEN     token pessoal (página "Tempo de tela" do app) — OBRIGATÓRIO
  DEVICE         rótulo enviado (default "mac")
  DEVICE_FILTER  "local"  = só o próprio Mac [default]
                 "remote" = só eventos sincronizados de outro device (vazio no macOS 26)
                 "all"    = tudo
  DAYS           quantos dias para trás reenviar (default 3)

Requisitos:
  - macOS logado na MESMA conta Apple do iPhone, com sync de Tempo de Uso ON.
  - O binário que roda isto (python3 / Terminal) precisa de FULL DISK ACCESS
    (Ajustes do Sistema > Privacidade e Segurança > Acesso Total ao Disco).

Heurística de device: no knowledgeC, eventos GERADOS no próprio Mac têm
ZSOURCE NULL; eventos SINCRONIZADOS de outro aparelho (iPhone/iPad/Watch) têm
ZSOURCE preenchido. Com só iPhone + Mac, "remote" ≈ iPhone. Ajuste se precisar.
"""
import json
import os
import shutil
import sqlite3
import tempfile
import urllib.request
from datetime import datetime, timedelta, timezone

KNOWLEDGE_DB = os.path.expanduser("~/Library/Application Support/Knowledge/knowledgeC.db")
COCOA_EPOCH = 978307200  # 2001-01-01 em segundos unix

# Mapa opcional bundle id -> nome amigável (apps de iOS). O resto cai no bundle id.
FRIENDLY = {
    "com.burbn.instagram": "Instagram",
    "com.zhiliaoapp.musically": "TikTok",
    "com.google.ios.youtube": "YouTube",
    "com.atebits.Tweetie2": "X (Twitter)",
    "net.whatsapp.WhatsApp": "WhatsApp",
    "com.facebook.Facebook": "Facebook",
    "com.toyopagroup.picaboo": "Snapchat",
    "com.apple.mobilesafari": "Safari",
    "com.reddit.Reddit": "Reddit",
    "com.linkedin.LinkedIn": "LinkedIn",
    "com.spotify.client": "Spotify",
    "com.netflix.Netflix": "Netflix",
    "ph.telegra.Telegraph": "Telegram",
    "com.hammerandchisel.discord": "Discord",
    "com.apple.MobileSMS": "Mensagens",
    "com.google.Gmail": "Gmail",
    "com.apple.mobilemail": "Mail",
}


def env(key, default=None):
    value = os.environ.get(key)
    return value if value not in (None, "") else default


def query_usage(days, device_filter):
    if not os.path.exists(KNOWLEDGE_DB):
        raise SystemExit(f"knowledgeC.db não encontrado em {KNOWLEDGE_DB} (Full Disk Access?).")

    since_cocoa = (datetime.now(timezone.utc) - timedelta(days=days)).timestamp() - COCOA_EPOCH
    src_clause = {
        "remote": "AND ZSOURCE IS NOT NULL",
        "local": "AND ZSOURCE IS NULL",
        "all": "",
    }.get(device_filter, "AND ZSOURCE IS NOT NULL")

    # Copia o DB (e WAL/SHM) para um tempdir 0600 que se autolimpa, para não
    # lidar com locks nem deixar um dump legível do banco (dado sensível) por aí.
    with tempfile.TemporaryDirectory() as tmpdir:
        dbcopy = os.path.join(tmpdir, "k.db")
        try:
            shutil.copy2(KNOWLEDGE_DB, dbcopy)
        except PermissionError as exc:
            raise SystemExit(
                "Sem permissão para ler o knowledgeC.db (proteção TCC do macOS).\n"
                "Dê FULL DISK ACCESS ao seu terminal:\n"
                "  Ajustes do Sistema > Privacidade e Segurança > Acesso Total ao Disco\n"
                "  -> ligue para o app de terminal que você usa (Terminal/iTerm/Ghostty/\n"
                "     VS Code/Warp...), depois FECHE (Cmd+Q) e reabra o terminal.\n"
                f"Detalhe: {exc}"
            ) from exc
        os.chmod(dbcopy, 0o600)
        for ext in ("-wal", "-shm"):
            try:
                shutil.copy2(KNOWLEDGE_DB + ext, dbcopy + ext)
                os.chmod(dbcopy + ext, 0o600)
            except FileNotFoundError:
                pass

        con = sqlite3.connect(dbcopy)
        try:
            return con.execute(
                f"""
                SELECT ZVALUESTRING AS bundle, ZSTARTDATE AS s, ZENDDATE AS e
                FROM ZOBJECT
                WHERE ZSTREAMNAME = '/app/usage'
                  AND ZVALUESTRING IS NOT NULL
                  AND ZSTARTDATE >= ?
                  {src_clause}
                """,
                (since_cocoa,),
            ).fetchall()
        finally:
            con.close()


def aggregate(rows):
    # {"2026-06-24": {bundle: seconds}}
    agg = {}
    for bundle, start, end in rows:
        if not bundle or start is None or end is None:
            continue
        duration = int(end - start)
        if duration <= 0:
            continue
        local_day = datetime.fromtimestamp(start + COCOA_EPOCH).strftime("%Y-%m-%d")
        agg.setdefault(local_day, {}).setdefault(bundle, 0)
        agg[local_day][bundle] += duration
    return agg


def post_day(endpoint, token, device, date, apps):
    body = json.dumps(
        {
            "device": device,
            "date": date,
            "apps": [
                {"bundle_id": bundle, "name": FRIENDLY.get(bundle, bundle), "seconds": seconds}
                for bundle, seconds in apps.items()
            ],
        }
    ).encode()
    req = urllib.request.Request(
        endpoint,
        data=body,
        method="POST",
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.status, resp.read().decode()


def main():
    endpoint = env("LIFE_ENDPOINT", "https://life.cesaroliveira.online/api/usage")
    token = env("LIFE_TOKEN")
    if not token:
        raise SystemExit("Defina LIFE_TOKEN (token da página 'Tempo de tela').")
    device = env("DEVICE", "mac")
    device_filter = env("DEVICE_FILTER", "local")
    days = int(env("DAYS", "3"))

    agg = aggregate(query_usage(days, device_filter))
    if not agg:
        print("Sem eventos de uso no período (sync já populou o Mac?).")
        return
    for date in sorted(agg):
        status, resp = post_day(endpoint, token, device, date, agg[date])
        print(f"{date}: {len(agg[date])} apps -> HTTP {status} {resp}")


if __name__ == "__main__":
    main()
