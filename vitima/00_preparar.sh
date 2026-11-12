#!/usr/bin/env bash
# Instala e configura auditd, rsyslog, AIDE, Osquery e utilitarios. Registra as versoes.
set -uo pipefail
source "$(dirname "$0")/comum.sh"; exige_root

log "Instalando pacotes"
apt-get update
apt-get install -y auditd rsyslog aide aide-common netcat-openbsd curl gnupg ca-certificates time bc tmux

log "Instalando Osquery (repositorio oficial)"
if ! command -v osqueryi >/dev/null; then
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://pkg.osquery.io/deb/pubkey.gpg -o /etc/apt/keyrings/osquery.asc
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/osquery.asc] https://pkg.osquery.io/deb deb main" \
    > /etc/apt/sources.list.d/osquery.list
  apt-get update && apt-get install -y osquery \
    || echo "ATENCAO: instale o Osquery manualmente (veja o ROTEIRO, passo 4)."
fi

log "Conferindo contas do experimento"
for u in alvo pesquisador; do id "$u" >/dev/null 2>&1 || { echo "Conta $u nao existe. Veja a etapa de configuracao do Debian."; exit 1; }; done
{ echo "uid_alvo=$(id -u alvo)"; echo "uid_pesquisador=$(id -u pesquisador)"; id alvo; id pesquisador; } | tee "$EVID/contas.txt"

log "Habilitando rsyslog (gera /var/log/auth.log e /var/log/syslog)"
systemctl enable --now rsyslog
logger -p auth.info "tcc: teste de configuracao do rsyslog"
sleep 1
grep -q "tcc: teste de configuracao" /var/log/auth.log && log "auth.log OK" || log "ATENCAO: auth.log nao recebeu a mensagem"

log "Configurando auditd.conf (sem rotacao durante o experimento)"
cp -n /etc/audit/auditd.conf /etc/audit/auditd.conf.original
sed -i -E 's/^max_log_file *=.*/max_log_file = 50/; s/^num_logs *=.*/num_logs = 8/; s/^max_log_file_action *=.*/max_log_file_action = ROTATE/' /etc/audit/auditd.conf
grep -E '^(max_log_file|num_logs|max_log_file_action|log_format|flush)' /etc/audit/auditd.conf | tee "$EVID/auditd_conf_parametros.txt"
# O auditd so le o auditd.conf ao iniciar: reinicia para aplicar a rotacao configurada
service auditd restart

log "Instalando regras do auditd (sem imutabilidade por enquanto)"
cp -n /etc/audit/rules.d/audit.rules /etc/audit/audit.rules.original 2>/dev/null || true
cp "$SCRIPTS/config/audit.rules" /etc/audit/rules.d/audit.rules
rm -f /etc/audit/rules.d/99-imutavel.rules
systemctl enable --now auditd
augenrules --load
auditctl -l | tee "$EVID/auditd_regras_carregadas.txt"
auditctl -s | tee "$EVID/auditd_status_preparacao.txt"

log "Instalando exclusoes do AIDE"
install -m 644 "$SCRIPTS/config/99_tcc_exclusoes" /etc/aide/aide.conf.d/99_tcc_exclusoes
aide --config "$AIDE_CONF" --config-check && log "aide.conf OK"

log "Desativando a verificacao diaria automatica do AIDE (dailyaidecheck), para que o AIDE so rode quando o experimento pedir"
systemctl disable --now dailyaidecheck.timer 2>/dev/null
systemctl is-enabled dailyaidecheck.timer 2>&1 | tee "$EVID/dailyaidecheck_estado.txt"

log "Criando dados simulados para a fase de exfiltracao"
install -d -o alvo -g alvo /home/alvo/dados_simulados
printf 'id,nome,email\n1,Cliente Ficticio A,a@exemplo.invalid\n2,Cliente Ficticio B,b@exemplo.invalid\n' \
  > /home/alvo/dados_simulados/clientes.csv
chown alvo:alvo /home/alvo/dados_simulados/clientes.csv

log "Registrando versoes e sincronizacao de relogio"
{
  echo "== Sistema"; cat /etc/os-release; uname -a
  echo "== Pacotes"; dpkg-query -W -f='${Package} ${Version}\n' auditd rsyslog aide osquery netcat-openbsd curl 2>/dev/null
  echo "== auditctl"; auditctl -v
  echo "== aide"; aide --version 2>&1 | head -1
  echo "== osqueryi"; osqueryi --version 2>/dev/null
  echo "== Relogio"; timedatectl
} | tee "$EVID/versoes.txt"
log "Preparacao concluida. Confira $EVID/versoes.txt"
