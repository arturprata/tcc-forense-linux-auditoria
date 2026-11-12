#!/usr/bin/env bash
# Recebe o arquivo enviado na acao E04. Deixe rodando antes de executar E04.
set -uo pipefail
echo "Aguardando conexao na porta 9001..."
if nc -h 2>&1 | grep -q -- "-N"; then nc -l 9001 > recebido.tar.gz   # netcat OpenBSD
else nc -l -p 9001 > recebido.tar.gz; fi                             # netcat tradicional
ls -l recebido.tar.gz && sha256sum recebido.tar.gz
