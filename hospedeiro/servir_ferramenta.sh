#!/usr/bin/env bash
# Disponibiliza um script inofensivo para a acao C02 (download de ferramenta simulada).
set -euo pipefail
mkdir -p ./servidor_ferramenta && cd ./servidor_ferramenta
printf '#!/bin/sh\necho "ferramenta simulada do experimento (sem efeito)"\n' > ferramenta.sh
echo "Servindo em http://0.0.0.0:8000/ferramenta.sh (Ctrl+C para encerrar)"
python3 -m http.server 8000
