#!/usr/bin/env bash
# Coleta das evidencias apos o cenario. Executar na sessao SSH do pesquisador, como root (sudo -i),
# DEPOIS de tirar o snapshot "final" no hospedeiro.
set -uo pipefail
source "$(dirname "$0")/comum.sh"; exige_root
C="$EVID/coleta"; mkdir -p "$C"/{logs,auditd,rsyslog,aide,historico,sistema}
TIMEFORMAT=%R
log "Inicio da coleta"

# 1. Copia bruta dos registros
cp -a /var/log/audit "$C/logs/"
cp -a /var/log/auth.log* /var/log/syslog* "$C/logs/" 2>/dev/null
journalctl --utc -o short-iso-precise > "$C/logs/journal.txt" 2>/dev/null

# 2. auditd: consultas por chave e relatorios
for k in comandos_executados alteracao_usuarios alteracao_senhas alteracao_grupos alteracao_sudoers \
         acesso_negado persistencia_cron alteracao_sshd persistencia_systemd alteracao_tmp alteracao_home \
         alteracao_permissoes alteracao_dono conexoes_saida modulos_kernel alteracao_auditoria uso_auditctl limpeza_logs; do
  ausearch -k "$k" -i > "$C/auditd/ausearch_$k.txt" 2>&1
done
ausearch -m CONFIG_CHANGE -i > "$C/auditd/ausearch_config_change.txt" 2>&1
aureport --summary          > "$C/auditd/aureport_resumo.txt" 2>&1
aureport -k --summary       > "$C/auditd/aureport_chaves.txt" 2>&1
aureport -x --summary       > "$C/auditd/aureport_executaveis.txt" 2>&1
aureport -au                > "$C/auditd/aureport_autenticacao.txt" 2>&1
aureport -m                 > "$C/auditd/aureport_contas.txt" 2>&1
aureport -l                 > "$C/auditd/aureport_logins.txt" 2>&1
aureport --failed           > "$C/auditd/aureport_falhas.txt" 2>&1

# 3. rsyslog: recortes relevantes
grep -E "sudo|useradd|usermod|sshd|session (opened|closed)" /var/log/auth.log > "$C/rsyslog/auth_relevante.txt"
grep -iE "cron" /var/log/syslog > "$C/rsyslog/syslog_cron.txt"

# 4. AIDE
{ time aide --config "$AIDE_CONF" --check > "$C/aide/aide_check.txt"; } 2> "$C/aide/tempo_aide_check.txt"
echo "codigo_saida=$?" >> "$C/aide/tempo_aide_check.txt"
cp /etc/aide/aide.conf.d/99_tcc_exclusoes "$C/aide/exclusoes_aide_final.txt" 2>/dev/null

# 5. Osquery (estado final)
"$SCRIPTS/snapshot_osquery.sh" depois

# 6. Historicos e artefatos de persistencia
for h in /home/*/.bash_history /root/.bash_history; do
  [ -f "$h" ] && cp -a "$h" "$C/historico/$(echo "$h" | tr / _)"
done
cp -a /var/spool/cron/crontabs "$C/sistema/" 2>/dev/null
cp -a /etc/sudoers.d "$C/sistema/" 2>/dev/null
cp -a /etc/passwd /etc/group "$C/sistema/"

# 7. Volume dos registros
{
  echo "fonte,bytes,linhas"
  for f in /var/log/audit/audit.log /var/log/auth.log /var/log/syslog "$C/aide/aide_check.txt"; do
    echo "$f,$(bytes "$f"),$(linhas "$f")"
  done
  echo "osquery_depois,$(du -sb "$EVID/osquery/depois" | cut -f1),"
} > "$C/volume_total.csv"
echo "audit_eventos_total=$(eventos_auditd)" >> "$C/volume_total.csv"
cp "$EVID"/contas.txt "$EVID"/marcadores_baseline.txt "$EVID"/versoes.txt "$EVID"/auditd_*.txt "$C/" 2>/dev/null
cp -a "$EVID/osquery" "$EVID/ruido" "$C/" 2>/dev/null
cp "$EVID"/overhead*.* "$C/" 2>/dev/null

# 8. Integridade das evidencias (cadeia de custodia)
( cd "$C" && find . -type f ! -name hashes.sha256 -print0 | sort -z | xargs -0 sha256sum > hashes.sha256 )
# Destino do pacote: pasta do usuario nao-root que invocou o sudo. Em caso de
# sudo -i encadeado, SUDO_USER pode virar "root"; nesse caso usa-se pesquisador.
DEST_USER="$ADMIN"; [ "$DEST_USER" = root ] && DEST_USER=pesquisador
DEST_HOME=$(getent passwd "$DEST_USER" | cut -d: -f6)
[ -d "$DEST_HOME" ] || DEST_HOME=/home/pesquisador
SAIDA="$DEST_HOME/coleta_vitima.tar.gz"
tar czf "$SAIDA" -C "$EVID" coleta
chown "$DEST_USER:$DEST_USER" "$SAIDA"
sha256sum "$SAIDA" | tee "$EVID/coleta_vitima.tar.gz.sha256"
log "Coleta concluida: $SAIDA"
