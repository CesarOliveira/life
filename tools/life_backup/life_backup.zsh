#!/bin/zsh
# Backup diario do banco do Life (https://life.integrattor.com.br).
# Baixa o dump (pg_dump, formato custom) de /ops/backup e guarda em ~/Backups/life.
# O token fica no Chaves do macOS (item "life-backup-token"), igual ao BACKUP_TOKEN do Railway:
#   security add-generic-password -U -s life-backup-token -a life -w
# Retencao: os 14 dumps mais recentes + o primeiro de cada mes (12 meses).
# Restaurar: ver "Backup e restauracao" em DEPLOY_OPERACOES.md do repositorio do Life.
set -u
URL="https://life.integrattor.com.br/ops/backup"
DEST="${LIFE_BACKUP_DEST:-$HOME/Backups/life}"   # LIFE_BACKUP_DEST: so para testes
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

TOKEN=$(/usr/bin/security find-generic-password -s life-backup-token -w 2>/dev/null)
if [ -z "$TOKEN" ]; then log "ERRO: token nao encontrado no Chaves (item life-backup-token)"; exit 2; fi
case "$DEST" in /*/*) ;; *) log "ERRO: destino invalido: $DEST"; exit 5 ;; esac

mkdir -p "$DEST" && chmod 700 "$DEST"
ARQ="$DEST/life-$(date +%Y-%m-%d).dump"
TMP="$ARQ.parcial"
# O token vai por arquivo de configuracao lido da entrada padrao, nao na linha de comando.
HTTP=$(printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" | /usr/bin/curl -sS --config - --max-time 300 -o "$TMP" -w '%{http_code}' "$URL")
if [ "$HTTP" != "200" ]; then rm -f "$TMP"; log "ERRO: o servidor respondeu HTTP $HTTP"; exit 3; fi
# Um dump do pg_dump em formato custom comeca com "PGDMP".
if [ "$(head -c 5 "$TMP")" != "PGDMP" ] || [ "$(stat -f %z "$TMP")" -lt 10000 ]; then rm -f "$TMP"; log "ERRO: arquivo baixado nao parece um dump valido"; exit 4; fi
mv "$TMP" "$ARQ" && chmod 600 "$ARQ"
log "ok: $ARQ ($(du -h "$ARQ" | cut -f1 | tr -d ' '))"

# Retencao: mantem os 14 mais recentes e o do dia 01 de cada mes (12 meses); apaga o resto.
# Os candidatos vem SO de padroes com caminho absoluto dentro de $DEST. O qualificador (N)
# devolve lista vazia quando nada casa — nunca se lista a pasta atual. E cada remocao
# confere de novo que o alvo e um arquivo life-AAAA-MM-DD.dump dentro de $DEST.
apagar() {
  local f="$1"
  case "$f" in
    "$DEST"/life-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].dump)
      if [ -f "$f" ] && rm -f -- "$f"; then log "removido ($2): ${f:t}"; else log "AVISO: nao foi possivel remover ${f:t}"; fi ;;
    *) log "AVISO: alvo fora do padrao ignorado: $f" ;;
  esac
}
todos=("$DEST"/life-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].dump(NOn))   # mais novo primeiro
if (( ${#todos} > 14 )); then
  for f in "${todos[@]:14}"; do
    [[ "$f" == *-01.dump ]] || apagar "$f" "retencao"
  done
fi
mensais=("$DEST"/life-[0-9][0-9][0-9][0-9]-[0-9][0-9]-01.dump(NOn))
if (( ${#mensais} > 12 )); then
  for f in "${mensais[@]:12}"; do apagar "$f" "retencao mensal"; done
fi
exit 0
