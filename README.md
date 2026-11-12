# Pacote de replicação: auditoria e monitoramento em Linux para análise forense

Material de replicação do Trabalho de Conclusão de Curso **"Análise Forense em Sistemas Linux: Configuração e Avaliação de Mecanismos de Auditoria para Registro de Atividades Suspeitas"**, de Artur Pigari Prata, Universidade Tecnológica Federal do Paraná (UTFPR), Campus Campo Mourão, 2026.

O experimento simula, em uma máquina virtual Debian 13, um comprometimento a partir de credenciais SSH válidas (34 ações em seis fases: reconhecimento, persistência, manipulação de arquivos, escalação de privilégios, exfiltração e limpeza de rastros) e avalia o que cada fonte de evidência registrou: `auditd`, `rsyslog`, *journal* do `systemd`, AIDE, Osquery e histórico do *shell*. As evidências são correlacionadas em uma *super timeline* com o log2timeline/Plaso.

> **Uso responsável:** os scripts executam ações de ataque simuladas (criação de usuário privilegiado, persistência, exfiltração por `netcat`, limpeza de *logs*). Execute-os **somente** em uma máquina virtual isolada e descartável, nunca em sistemas de produção ou de terceiros.

## Estrutura

| Pasta / arquivo | Conteúdo |
|---|---|
| `ROTEIRO.md` | Sequência completa de comandos, do hospedeiro à análise |
| `vitima/` | Scripts executados na máquina vítima: preparação, medição de sobrecarga e ruído, *baseline*, capturas do Osquery e coleta |
| `vitima/config/` | Regras do `auditd`, regra de imutabilidade e exclusões do AIDE |
| `hospedeiro/` | Scripts da máquina hospedeira: plano de ações, registro do gabarito, *snapshots*, servidor da ferramenta simulada, receptor da exfiltração e geração da *timeline* com o Plaso |
| `analise/` | Scripts de análise: gabarito, normalização do `auditd`, diferenças do Osquery, volume por fase, *super timeline* e conjunto mínimo de fontes |
| `dados/` | Evidências e resultados intermediários da execução realizada em 12/11/2026 (UTC) |
| `resultados/` | Tabela de cobertura (ação × fonte) e cálculo do conjunto mínimo |

## Ambiente utilizado

| Componente | Versão |
|---|---|
| Hospedeiro | Linux Mint 22.3, AMD Ryzen 9 9950X3D, 32 GB de RAM |
| Virtualização | VirtualBox 7.2.22 (VM com 2 vCPU, 2 GB de RAM, 20 GB de disco, NAT + *host-only*) |
| Vítima | Debian 13.7 (`debian-13.7.0-amd64-netinst.iso`), *kernel* 6.12.116+deb13-amd64 |
| Auditoria | auditd 4.0.2, rsyslog 8.2504.0, AIDE 0.19.1, Osquery 5.24.1 |
| Correlação | Plaso 20261027 (imagem Docker `log2timeline/plaso`), Docker 29.9.3, Python 3 |

## Como reproduzir

1. Crie a VM e instale o Debian conforme a seção 3 do `ROTEIRO.md` (contas `pesquisador` e `alvo`, IP fixo `192.168.56.10` na rede *host-only*).
2. Ajuste `hospedeiro/ambiente.conf`, se necessário.
3. Siga o `ROTEIRO.md` na ordem: preparação (`00_preparar.sh`), sobrecarga (`01_medir_overhead.sh 5000 5`), ruído (`02_medir_ruido.sh 60`), *baseline* (`03_baseline.sh`), cenário (ações de `hospedeiro/plano_acoes.tsv`, registradas com `registrar_acao.sh`), coleta (`04_coletar.sh`) e análise (`analise/`).
4. Gere a chave SSH usada na ação B03 com `ssh-keygen`; a chave privada não faz parte deste repositório.

## Dados incluídos

- `dados/gabarito.csv`: ações executadas, com horário UTC registrado no hospedeiro.
- `dados/audit_eventos.csv`, `dados/osquery_diff.csv`, `dados/super_timeline.csv`, `dados/volume_por_fase.csv`: resultados dos scripts de análise.
- `dados/auditd/`, `dados/rsyslog/`, `dados/aide/`, `dados/osquery/`, `dados/historico/`, `dados/sistema/`: extratos da coleta.
- `dados/caderno_de_campo.md`: registro da execução, incluindo as ocorrências fora do esperado.
- `dados/hashes.sha256`: resumos SHA-256 dos arquivos coletados. O arquivo `dados/auditd/ausearch_comandos_executados.txt` foi compactado com `xz` por causa do tamanho; o resumo registrado refere-se ao conteúdo descompactado (`xz -dc arquivo.xz | sha256sum`).

Não estão incluídos: imagens de disco da VM (`.vdi`, `.raw`), o arquivo `.plaso` e a chave privada de teste. O pacote bruto da coleta (`coleta_vitima.tar.gz`) está disponível na seção *Releases* (versão v1.0), com seu resumo SHA-256. As imagens de disco e os *snapshots* da máquina virtual são mantidos pelo autor e podem ser disponibilizados mediante solicitação.

Observações sobre os dados: a captura intermediária do Osquery (ação X01) foi executada, por engano, a partir da sessão da conta `alvo`; por isso, os registros entre 04:35:00 e 04:40:30 UTC foram desconsiderados na análise (`--excluir-janela`). Detalhes no caderno de campo e no Capítulo 4 do trabalho.

## Principais resultados

- O `auditd` registrou de forma completa 32 das 34 ações e parcialmente as outras duas (cobertura ponderada de 97,1%), com sobrecarga de 15,5% na execução de comandos. Detecção completa exige identificar a ação, o objeto e o momento com precisão de segundos; a cobertura ponderada atribui 1 à detecção completa e 0,5 à parcial.
- Sem o `auditd`, a melhor combinação das demais fontes (*journal*, AIDE e Osquery) obteve cobertura ponderada de 51,5%, com algum registro para 64,7% das ações.
- O Plaso 20261027 não gerou eventos a partir do `audit.log` em formato `ENRICHED`, que contém o caractere de controle 0x1d; por isso os registros do `auditd` foram normalizados por `analise/normalizar_auditd.py`.
- A remoção seletiva de linhas do `auth.log` com `sed -i` interrompeu a gravação do arquivo pelo `rsyslog`; o *journal* do `systemd` preservou os registros removidos.

## Licença

Scripts e configurações: licença MIT (`LICENSE`). Dados e documentação: Creative Commons Atribuição 4.0 Internacional (CC BY 4.0), conforme `LICENSE-DADOS`.

## Como citar

PRATA, Artur Pigari. **Análise forense em sistemas Linux**: configuração e avaliação de mecanismos de auditoria para registro de atividades suspeitas. 2026. Trabalho de Conclusão de Curso (Graduação) – Universidade Tecnológica Federal do Paraná, Campo Mourão, 2026.
