#!/usr/bin/env python3
"""Exporta o Tempo de Uso do iPhone (sincronizado para este Mac) para CSVs no Google Drive.

Fonte: ~/Library/Biome/streams/restricted/App.InFocus/remote/<dispositivo>/ (arquivos SEGB v2).
Os arquivos sao COPIADOS para /tmp antes de serem lidos; nada e escrito na pasta do Biome.

Uso:
  tempodetela.py                  # ontem (America/Sao_Paulo)
  tempodetela.py 2026-11-09       # um dia especifico
  tempodetela.py --dias 3         # reexporta os 3 ultimos dias terminando em D (cobre atraso de sincronizacao)
  tempodetela.py --saida /tmp/x   # grava em outra pasta (teste)

Saida: um unico arquivo acumulado apps.csv (data,app,minutos); os dias exportados substituem as proprias linhas.
"""
import argparse, csv, datetime, glob, json, os, shutil, struct, subprocess, sys, tempfile, urllib.error, urllib.request, zoneinfo

# ---------------------------------------------------------------- configuracao
TZ = zoneinfo.ZoneInfo("America/Sao_Paulo")
DEVICE_ID = "COLE-AQUI-O-ID-DO-IPHONE"   # pasta em App.InFocus/remote/; ver DevicePeer em ~/Library/Biome/sync/sync.db
STREAM = os.path.expanduser("~/Library/Biome/streams/restricted/App.InFocus/remote")
DRIVE_GLOB = os.path.expanduser("~/Library/CloudStorage/GoogleDrive-*/Meu Drive")
PASTA_DESTINO = "TempoDeTela"
NOMES_JSON = os.path.join(os.path.dirname(os.path.abspath(__file__)), "nomes_apps.json")  # dicionario editavel
# Telas do sistema que o Tempo de Uso do iPhone nao lista como app:
EXCLUIR_PREFIXOS = ("com.apple.springboard",)
EXCLUIR = {"com.apple.ScreenshotServicesService", "com.apple.control-center", "com.apple.ScreenTimeUnlock",
           "com.apple.CarPlaySplashScreen", "com.apple.PosterBoard"}
# --- envio para o site Life (alem do CSV). O token fica no Chaves do macOS, nunca neste arquivo:
#     security add-generic-password -U -s tempodetela-life -a life -w
LIFE_ENDPOINT = "https://life.cesaroliveira.online/api/usage"
LIFE_KEYCHAIN = "tempodetela-life"
LIFE_DEVICE = "iphone"                      # mesmo rotulo que o Atalho usava
LIFE_DESDE = datetime.date(2026, 10, 15)    # primeiro dia completo do historico do Mac; o Atalho nao cobriu esse periodo
COCOA = 978307200  # segundos entre 1970 e 2001


def log(msg):
    print(f"{datetime.datetime.now(TZ):%Y-%m-%d %H:%M:%S} {msg}", flush=True)


# ---------------------------------------------------------------- SEGB v2 + protobuf
def _varint(b, i):
    r = s = 0
    while True:
        c = b[i]; i += 1
        r |= (c & 0x7F) << s; s += 7
        if not c & 0x80:
            return r, i


def _pb(b):
    out = {}; i = 0
    while i < len(b):
        key, i = _varint(b, i); f, wt = key >> 3, key & 7
        if wt == 0: v, i = _varint(b, i)
        elif wt == 1: v = struct.unpack_from("<d", b, i)[0]; i += 8
        elif wt == 2: ln, i = _varint(b, i); v = b[i:i + ln]; i += ln
        elif wt == 5: v = struct.unpack_from("<f", b, i)[0]; i += 4
        else: raise ValueError("wire type")
        out.setdefault(f, v)
    return out


def _registros(path):
    """Registros vivos de um SEGB v2: indice de 16 bytes crescendo do fim do arquivo para tras."""
    with open(path, "rb") as fh:
        b = fh.read()
    if b[:4] != b"SEGB":
        return
    n = len(b); prev_end = 0x20; k = 0
    while True:
        e = n - 16 * (k + 1); k += 1
        if e < 0x20: break
        off, state = struct.unpack_from("<II", b, e)
        if off == 0: break
        start = ((prev_end + 3) & ~3) + 8; end = 0x20 + off
        if end < start or end > n: break
        prev_end = end
        if state == 1:
            yield b[start:end]


def eventos(pasta):
    """Lista ordenada de (t_cocoa, bundle, inicio?) dos apps (tipo 1) em foco."""
    evs = []
    for f in sorted(glob.glob(os.path.join(pasta, "[0-9]*"))):
        if not os.path.isfile(f): continue
        for data in _registros(f):
            try: p = _pb(data)
            except Exception: continue
            if 6 not in p or 4 not in p or 3 not in p or p.get(2) != 1: continue
            evs.append((p[4], p[6].decode("utf-8", "replace"), p[3] == 1))
    evs.sort()
    return evs


# ---------------------------------------------------------------- calculo
def segundos_por_app(evs, dia):
    d0 = datetime.datetime(dia.year, dia.month, dia.day, tzinfo=TZ)
    t0 = d0.timestamp() - COCOA
    t1 = (d0 + datetime.timedelta(days=1)).timestamp() - COCOA   # respeita o fuso local
    aberto = {}; secs = {}
    for t, b, inicio in evs:
        if inicio:
            aberto[b] = t
        elif b in aberto:
            lo = max(aberto.pop(b), t0); hi = min(t, t1)
            if hi > lo: secs[b] = secs.get(b, 0.0) + (hi - lo)
    return {b: s for b, s in secs.items() if b not in EXCLUIR and not b.startswith(EXCLUIR_PREFIXOS)}


SLOT = 15 * 60  # blocos de 15 minutos (96 por dia)


def segundos_por_bloco(evs, dia):
    """{(bloco 0..95, bundle): segundos} do dia local: mesmo pareamento inicio->fim, repartido em blocos de 15 min."""
    d0 = datetime.datetime(dia.year, dia.month, dia.day, tzinfo=TZ)
    t0 = d0.timestamp() - COCOA
    t1 = (d0 + datetime.timedelta(days=1)).timestamp() - COCOA
    aberto = {}; blocos = {}
    for t, b, inicio in evs:
        if inicio:
            aberto[b] = t; continue
        if b not in aberto: continue
        lo = max(aberto.pop(b), t0); hi = min(t, t1)
        if hi <= lo or b in EXCLUIR or b.startswith(EXCLUIR_PREFIXOS): continue
        while lo < hi:
            # bloco pelo relogio local (em dia de troca de horario de verao o dia nao tem 96 blocos iguais)
            local = datetime.datetime.fromtimestamp(lo + COCOA, TZ)
            n = local.hour * 4 + local.minute // 15
            fim_bloco = lo - ((local.minute % 15) * 60 + local.second + local.microsecond / 1e6) + SLOT
            ate = min(hi, fim_bloco)
            blocos[(n, b)] = blocos.get((n, b), 0.0) + (ate - lo)
            lo = ate
    return blocos


def nome_legivel(bundle, nomes):
    if bundle in nomes: return nomes[bundle]
    partes = [x for x in bundle.split(".") if x]
    while len(partes) > 1 and partes[-1].lower() in ("app", "ios", "iphone", "mobile", "prod", "client"):
        partes.pop()   # com.getfinit.app -> "Getfinit" em vez de "App"
    ult = partes[-1] if partes else bundle
    return ult[:1].upper() + ult[1:]


ARQUIVO = "apps.csv"   # arquivo unico e acumulado: data,app,minutos


def minutos_por_app(secs, nomes):
    por_nome = {}
    for b, s in secs.items():
        n = nome_legivel(b, nomes); por_nome[n] = por_nome.get(n, 0.0) + s
    linhas = sorted(((n, round(s / 60)) for n, s in por_nome.items()), key=lambda x: (-x[1], x[0]))
    return [(n, m) for n, m in linhas if m >= 1]


def life_token():
    try:
        r = subprocess.run(["/usr/bin/security", "find-generic-password", "-s", LIFE_KEYCHAIN, "-w"],
                           capture_output=True, text=True, timeout=20)
    except Exception:
        return None
    return r.stdout.strip() or None if r.returncode == 0 else None


def enviar_life(token, dia, secs, nomes, blocos=None):
    """POST /api/usage de um dia. A chave do app e o NOME (como o Atalho enviava), para o historico
    e os habitos do site continuarem batendo. O servidor faz upsert: reenviar o dia sobrescreve."""
    por_nome = {}
    for b, s in secs.items():
        n = nome_legivel(b, nomes); por_nome[n] = por_nome.get(n, 0.0) + s
    apps = [{"bundle_id": n, "name": n, "seconds": round(s)} for n, s in por_nome.items() if round(s) > 0]
    payload = {"device": LIFE_DEVICE, "date": dia.isoformat(), "apps": apps}
    if blocos is not None:   # uso em blocos de 15 min, com a mesma chave (nome) do total do dia
        por_bloco = {}
        for (n, b), s in blocos.items():
            chave = (n, nome_legivel(b, nomes)); por_bloco[chave] = por_bloco.get(chave, 0.0) + s
        payload["slots"] = [{"slot": n, "bundle_id": nome, "name": nome, "seconds": min(round(s), SLOT)}
                            for (n, nome), s in sorted(por_bloco.items()) if round(s) > 0]
    body = json.dumps(payload).encode()
    req = urllib.request.Request(LIFE_ENDPOINT, data=body, method="POST", headers={
        "Content-Type": "application/json", "Authorization": f"Bearer {token}", "User-Agent": "tempodetela-mac/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            r = json.loads(resp.read().decode() or "{}")
        log(f"Life {dia}: enviado, {r.get('upserted', '?')} apps e {r.get('slots', 0) or 0} blocos de 15 min gravados"); return True
    except urllib.error.HTTPError as e:
        log(f"ERRO Life {dia}: HTTP {e.code} {e.read().decode(errors='replace')[:200]}")
    except Exception as e:
        log(f"ERRO Life {dia}: {e}")
    return False


def gravar(novos, destino):
    """novos = {data_iso: [(app, minutos)]}. Substitui no apps.csv as linhas desses dias e mantem as demais."""
    caminho = os.path.join(destino, ARQUIVO); dias = {}
    if os.path.exists(caminho):
        with open(caminho, newline="", encoding="utf-8") as fh:
            for r in csv.DictReader(fh):
                try: dias.setdefault(r["data"], []).append((r["app"], int(r["minutos"])))
                except (KeyError, ValueError, TypeError): continue
    dias.update(novos)
    with open(caminho, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh); w.writerow(["data", "app", "minutos"])
        for d in sorted(dias):
            w.writerows([d, n, m] for n, m in sorted(dias[d], key=lambda x: (-x[1], x[0])))
    return caminho, len(dias)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("dia", nargs="?", help="AAAA-MM-DD (padrao: ontem)")
    ap.add_argument("--dias", type=int, default=1, help="quantos dias exportar, terminando em D (padrao 1)")
    ap.add_argument("--saida", help="pasta de destino alternativa")
    ap.add_argument("--device", default=DEVICE_ID)
    ap.add_argument("--sem-life", action="store_true", help="nao envia ao site Life (so CSV)")
    a = ap.parse_args()
    fim = (datetime.date.fromisoformat(a.dia) if a.dia
           else datetime.datetime.now(TZ).date() - datetime.timedelta(days=1))

    if a.saida:
        destino = a.saida
    else:
        drives = sorted(glob.glob(DRIVE_GLOB))
        if not drives:
            log("ERRO: Google Drive para desktop nao encontrado em ~/Library/CloudStorage/GoogleDrive-*/Meu Drive"); return 3
        destino = os.path.join(drives[0], PASTA_DESTINO)
    os.makedirs(destino, exist_ok=True)

    origem = os.path.join(STREAM, a.device)
    tmp = tempfile.mkdtemp(prefix="tempodetela-", dir="/tmp")
    try:
        try:
            os.listdir(origem)  # glob esconde erro de permissao; isto falha de forma explicita sem Acesso Total ao Disco
            arquivos = [f for f in glob.glob(os.path.join(origem, "[0-9]*")) if os.path.isfile(f)]
            for f in arquivos: shutil.copy2(f, tmp)
        except (PermissionError, FileNotFoundError) as e:
            log(f"ERRO: sem acesso a {origem} ({e}). De Acesso Total ao Disco a ~/Scripts/tempodetela/tempodetela-runner (launchd) ou ao app de terminal (execucao manual)"); return 2
        if not arquivos:
            log(f"ERRO: nenhum arquivo SEGB em {origem}"); return 2
        evs = eventos(tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if not evs:
        log("ERRO: nenhum evento lido"); return 2
    ultimo = datetime.datetime.fromtimestamp(evs[-1][0] + COCOA, TZ)
    log(f"{len(evs)} eventos do iPhone; ultimo registro sincronizado: {ultimo:%Y-%m-%d %H:%M}")

    try:
        with open(NOMES_JSON, encoding="utf-8") as fh: nomes = json.load(fh)
    except FileNotFoundError:
        nomes = {}
    novos = {}; brutos = {}
    for i in range(a.dias - 1, -1, -1):
        dia = fim - datetime.timedelta(days=i)
        brutos[dia] = segundos_por_app(evs, dia)
        linhas = minutos_por_app(brutos[dia], nomes)
        if not linhas:
            log(f"{dia}: sem dados sincronizados; linhas existentes mantidas"); continue
        novos[dia.isoformat()] = linhas
        aviso = "" if ultimo.date() > dia else "  [AVISO: dia ainda incompleto na sincronizacao]"
        top = ", ".join(f"{n} {m}" for n, m in linhas[:5])
        log(f"{dia}: total {sum(m for _, m in linhas)} min, {len(linhas)} apps ({top}){aviso}")
    caminho, n = gravar(novos, destino)
    log(f"gravado em {caminho} ({n} dias no arquivo)")

    # Envio ao Life: so o destino real (nao em --saida de teste) e so dias a partir de LIFE_DESDE.
    if a.sem_life or a.saida:
        return 0
    # So dias COMPLETOS vao para o Life: um dia so esta fechado quando ja chegou algum evento do dia seguinte.
    # Enviar o dia pela metade marcaria errado os habitos de limite ("tela no maximo X horas").
    dias_life = [d for d in sorted(brutos) if d >= LIFE_DESDE and brutos[d] and ultimo.date() > d]
    pendentes = [d for d in sorted(brutos) if d >= LIFE_DESDE and brutos[d] and ultimo.date() <= d]
    if pendentes:
        log(f"Life: aguardando sincronizacao completa de {', '.join(str(d) for d in pendentes)} (nao enviado ainda)")
    if not dias_life:
        log("Life: nenhum dia completo a enviar"); return 0
    token = life_token()
    if not token:
        log(f"ERRO Life: token nao encontrado no Chaves (item '{LIFE_KEYCHAIN}'); CSV gravado, envio pulado"); return 4
    ok = all([enviar_life(token, d, brutos[d], nomes, segundos_por_bloco(evs, d)) for d in dias_life])
    return 0 if ok else 4


if __name__ == "__main__":
    sys.exit(main())
