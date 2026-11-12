#!/usr/bin/env python3
"""Calcula a cobertura de todas as combinacoes de fontes a partir de cobertura.csv
(valores Sim=1, Parcial=0,5, Nao=0) e indica a menor combinacao com cobertura maxima.
Uso: python3 conjunto_minimo.py cobertura.csv [conjunto_minimo.csv]"""
import csv, itertools, sys, unicodedata

VALOR = {"sim": 1.0, "parcial": 0.5, "nao": 0.0, "": 0.0}
def norm(s):
    return unicodedata.normalize("NFKD", s.strip().lower()).encode("ascii", "ignore").decode()

with open(sys.argv[1], encoding="utf-8") as f:
    linhas = list(csv.DictReader(f))
fontes = [c for c in linhas[0] if c not in ("id", "acao", "evidencia_observada")]
mat = [[VALOR[norm(r[c])] for c in fontes] for r in linhas]
n = len(mat)
resultados = []
for k in range(1, len(fontes) + 1):
    for comb in itertools.combinations(range(len(fontes)), k):
        melhor = [max(lin[i] for i in comb) for lin in mat]
        resultados.append((sum(melhor), sum(1 for v in melhor if v == 1), k, "+".join(fontes[i] for i in comb)))
maximo = max(r[0] for r in resultados)
resultados.sort(key=lambda r: (-r[0], r[2]))
if len(sys.argv) > 2:
    with open(sys.argv[2], "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["combinacao", "n_fontes", "pontuacao", "cobertura_percentual", "acoes_completas"])
        for p, c, k, nome in resultados:
            w.writerow([nome, k, p, round(100 * p / n, 1), c])
print(f"{n} acoes; pontuacao maxima possivel com todas as fontes: {maximo} ({100*maximo/n:.1f}%)")
for k in range(1, len(fontes) + 1):
    p, c, _, nome = max((r for r in resultados if r[2] == k), key=lambda r: r[0])
    print(f"Melhor com {k} fonte(s): {nome:45s} {100*p/n:5.1f}%  ({c} acoes completas)")
minimo = min((r for r in resultados if r[0] == maximo), key=lambda r: r[2])
print(f"Conjunto minimo com cobertura maxima: {minimo[3]}")
isolado = {fontes[i]: 100 * sum(l[i] for l in mat) / n for i in range(len(fontes))}
print("Cobertura isolada:", ", ".join(f"{k}={v:.1f}%" for k, v in isolado.items()))
