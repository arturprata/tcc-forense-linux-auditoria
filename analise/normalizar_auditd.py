#!/usr/bin/env python3
"""Agrupa os registros do audit.log por evento (numero de serie) e gera um CSV com
uma linha por evento: horario UTC, chave da regra, usuario de login (auid), comando e caminhos.
Uso: python3 normalizar_auditd.py audit.log audit_eventos.csv"""
import csv, re, sys
from datetime import datetime, timezone

RE_MSG = re.compile(r"type=(\S+) msg=audit\((\d+\.\d+):(\d+)\):(.*)")
RE_CAMPO = re.compile(r'(\w+)=("([^"]*)"|\S+)')

def decodifica(v, hexa=False):
    """Remove aspas. Argumentos do EXECVE com espacos ou caracteres especiais vem em hexadecimal."""
    if v.startswith('"'):
        return v.strip('"')
    if hexa and re.fullmatch(r"[0-9A-F]+", v) and len(v) % 2 == 0:
        try:
            return bytes.fromhex(v).decode("utf-8", "replace").replace("\x00", " ")
        except ValueError:
            pass
    return v

eventos = {}
with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
    for linha in f:
        m = RE_MSG.search(linha)
        if not m:
            continue
        tipo, ts, serie, resto = m.groups()
        ev = eventos.setdefault(serie, {"ts": float(ts), "tipos": [], "campos": {}, "args": {}, "caminhos": []})
        ev["tipos"].append(tipo)
        campos = {k: decodifica(v, hexa=(tipo == "EXECVE" and re.fullmatch(r"a\d+", k) is not None))
                  for k, v, _ in RE_CAMPO.findall(resto)}
        if tipo == "EXECVE":
            ev["args"].update({k: v for k, v in campos.items() if re.fullmatch(r"a\d+", k)})
        elif tipo == "PATH":
            if "name" in campos:
                ev["caminhos"].append(f'{campos["name"]}({campos.get("nametype", "")})')
        else:
            for k in ("key", "auid", "uid", "euid", "comm", "exe", "success", "exit", "syscall", "res", "op", "acct", "addr"):
                if k in campos and k not in ev["campos"]:
                    ev["campos"][k] = campos[k]

with open(sys.argv[2], "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["timestamp_utc", "fonte", "tipo", "descricao", "serie", "auid", "chave"])
    for serie, ev in sorted(eventos.items(), key=lambda x: (x[1]["ts"], int(x[0]))):
        c = ev["campos"]
        cmd = " ".join(ev["args"][k] for k in sorted(ev["args"], key=lambda a: int(a[1:])))
        partes = [f"{k}={c[k]}" for k in ("comm", "exe", "uid", "euid", "success", "exit", "op", "acct", "res") if k in c]
        if cmd:
            partes.append(f"cmd={cmd}")
        if ev["caminhos"]:
            partes.append("caminhos=" + ";".join(ev["caminhos"]))
        quando = datetime.fromtimestamp(ev["ts"], tz=timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
        chave = c.get("key", "").strip('"')
        w.writerow([quando, "auditd", chave if chave not in ("", "(null)") else "+".join(dict.fromkeys(ev["tipos"])),
                    " ".join(partes), serie, c.get("auid", ""), chave])
print(f"{len(eventos)} eventos normalizados em {sys.argv[2]}")
