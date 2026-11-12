#!/usr/bin/env bash
# Gera a timeline com Plaso (via Docker) a partir da imagem RAW do snapshot final.
# Uso: ./timeline_plaso.sh /caminho/vitima_final.raw
set -euo pipefail
IMG=$(realpath "${1:?informe a imagem .raw}")
DIR="$(cd "$(dirname "$0")" && pwd)"
SAIDA="$DIR/plaso"; mkdir -p "$SAIDA"
cp "$DIR/filtro_plaso.yaml" "$SAIDA/"
cd "$SAIDA"
docker pull log2timeline/plaso
docker run --rm log2timeline/plaso log2timeline --version | tee versao_plaso.txt
sha256sum "$IMG" | tee imagem.sha256
TIMEFORMAT=%R
{ time docker run --rm -v "$SAIDA":/data -v "$(dirname "$IMG")":/img:ro log2timeline/plaso \
    log2timeline --storage-file /data/timeline.plaso --parsers linux \
    --partitions all --volumes all --unattended \
    --file-filter /data/filtro_plaso.yaml "/img/$(basename "$IMG")"; } 2> tempo_log2timeline.txt
docker run --rm -v "$SAIDA":/data log2timeline/plaso pinfo /data/timeline.plaso > pinfo.txt
docker run --rm -v "$SAIDA":/data log2timeline/plaso \
    psort -o l2tcsv --output_time_zone UTC -w /data/timeline_plaso.csv /data/timeline.plaso
echo "Gerado: $SAIDA/timeline_plaso.csv (veja pinfo.txt para os parsers usados)"
