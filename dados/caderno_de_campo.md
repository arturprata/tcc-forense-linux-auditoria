# Caderno de campo do experimento

## Ambiente
- Data da execução: 11/11/2026 (horário local) / 12/11/2026 (UTC)
- Linux Mint (versão): 22.3
- Processador e memória da máquina real: AMD Ryzen 9 9950X3D; 32 GB de RAM DDR5 (2 × 16 GB, 6000 MT/s)
- VirtualBox / Docker / Plaso (versões): 7.2.22r175245 / 29.9.3 / 20261027
- Kernel do Mint (uname -r): 7.0.0-43-generic
- ISO do Debian: debian-13.7.0-amd64-netinst.iso (SHA-256 a7ef94ac2fb9a7fec454552abd629b7cc9d5155c886165a45649f5ce6167e355)
- Instalação do Debian: manual (instalação desassistida desativada), apenas servidor SSH e utilitários padrão
- Interfaces da VM (NAT e host-only): enp0s3; enp0s8
- IP da vítima / IP do Mint: 192.168.56.10 / 192.168.56.1
- uid_alvo / uid_pesquisador (coleta/contas.txt): 1001 / 1000
- Diferença de relógio Mint x VM (s): na Etapa 3: 0 s (00:52:41 UTC nos dois); antes do A01: 0 s (04:09:03 UTC nos dois)
- SHA-256 da imagem original: d5fb44ddb65856d09008dff3904351cf6d734957c62e79149546a0cd83fcb817
- Debian / kernel da VM: 13.7 / 6.12.116+deb13-amd64
- auditd / rsyslog / AIDE / Osquery: 4.0.2 / 8.2504.0 / 0.19.1 / 5.24.1

## Preparação
- Avisos ou erros do 00_preparar.sh: 15 avisos "Old style watch rules are slower" (informativos, regras -w); pacote do AIDE instalou exim4 e dailyaidecheck.timer como dependências; timer desativado manualmente
- Quantidade de regras carregadas no auditd: 24
- Overhead (tempo com regras / sem regras / sobrecarga % / bytes por comando): 3,242 s / 2,807 s / 15,5% / 1.351 bytes (5 repetições de 5.000 execuções; 2ª medição, válida; 1ª descartada por erro de locale e rotação)
- Ruído: 1 rodada de 60 min (01:36 a 02:36 UTC); 116 eventos do auditd (163.231 bytes, 3,74 MB/dia); auth.log 2 linhas, syslog 1 linha; 1 caminho alterado no AIDE; retenção estimada de 107,1 dias com o sistema ocioso; tempo AIDE: init 20,4 s, check 16,5 s (40.575 entradas)
- Caminhos excluídos do AIDE e motivo de cada um: nenhum além das exclusões iniciais; única alteração no ruído foi /var/log/audit/audit.log (crescimento esperado; mantido no monitoramento para detectar remoção ou truncamento)
- Hora UTC do fim da baseline: 2026-11-12T04:03:04.195Z (01:03:04 Brasília); SHA-256 da base do AIDE: cc7202cd61428127bbda49a74be89689b39145b518497f8d82a9d10884791483; snapshot Osquery "antes" em 3,096 s

## Temporizadores do sistema (Brasília)
- dpkg-db-backup e exim4-base executados 00:00:05; logrotate 00:30:35; próximo (apt-daily-upgrade) 06:15. Baseline e cenário executados na janela livre entre o logrotate e o apt-daily-upgrade.
- A janela de ruído (22:36 a 23:36, Brasília) não incluiu tarefas diárias do sistema; representa o sistema em repouso entre elas.

## Snapshots (nome e horário UTC)
- 00-instalacao-limpa: 2026-11-12T00:59:17Z
- 01-ferramentas: 2026-11-12T01:15:30Z
- 02-baseline: 2026-11-12T04:05:03Z
- fase-a a fase-e: não utilizados; separação das fases feita pelos horários do gabarito
- final: 2026-11-12T04:43:19Z

## Execução do cenário
Cenário executado de 04:10:34 a 04:41:55 UTC (34 ações A01–F05 mais a captura X01).

### Ocorrências fora do esperado
| ID | Hora aprox. (UTC) | O que aconteceu | O que fiz |
|----|-------------------|-----------------|-----------|
| Etapa 1 | 00:05 | `usermod` falhou: grupo vboxusers não existia | Adicionado só o grupo docker; vboxusers não é necessário (sem USB) |
| Etapa 1 | 00:07 | VirtualBox 7.0.16 do repositório do Mint não compilou o módulo para o kernel 7.0 | Removido e instalado o VirtualBox 7.2.22 do repositório da Oracle |
| Etapa 2 | 00:25 | Assistente do VirtualBox ativou a instalação desassistida por padrão | Opção desmarcada; instalação manual |
| Etapa 3 | 00:58 | Scripts extraídos sem permissão de execução | Corrigido com `chmod +x` |
| Etapa 3 | 00:58 | Segundo `startvm` deu erro "already locked" | Sem efeito: a VM já estava ligada |
| Etapa 4 | 01:24 | 1ª medição de overhead descartada: médias arredondadas pelo locale pt_BR e bytes negativos (auditd não tinha relido auditd.conf; log rotacionava a cada 8 MiB) | Scripts corrigidos (LC_NUMERIC=C, soma de todos os audit.log*), auditd reiniciado, medição refeita |
| Etapa 4 | 04:03 | Osquery: logged_in_users vazia porque /var/run/utmp não existe no Debian 13; tabela last funciona (lê /var/log/wtmp) | Sem alteração; registrado como limitação do Osquery nesta versão |
| B03 | 04:23 | Comando executado (04:23:24, pelo auditd) antes de ser registrado (04:24:09) | Registro cerca de 45 s atrasado; eventos associados ao B03 pelo conteúdo e pelo horário do auditd |
| X01 | 04:36 | Captura digitada por engano no terminal do alvo; falhou sem sudo (sem acesso a /root), depois executada com sudo a partir da sessão do alvo | Captura salva corretamente; eventos do osqueryi ficaram com auid=1001 e não podem ser separados pelo auid. Na análise, descartados os registros do auditd e do rsyslog entre 04:35:00 e 04:40:30 UTC (só contém a captura e sua verificação); conteúdo da captura mantido |
| Coleta | 04:47 | 04_coletar.sh gravou o pacote em /home/root (SUDO_USER=root por causa de sudo -i encadeado) | Pacote refeito manualmente em /home/pesquisador; script corrigido para usar pesquisador quando SUDO_USER=root |

## Saídas a registrar
- D01 (mensagem): cat: /etc/shadow: Permissão negada
- D05 (saída): uid=0(root) gid=0(root) grupos=0(root)
- E04 (tamanho e hash recebidos no Mint): 660 bytes; 3ed2607a9066cf7e4b5221a154c823da25b93514f01050f995ff5f2adf0fa577
- X01 (tempo do snapshot do Osquery): 3,101 s (captura "durante"); confirmou invasor_teste em usuarios.json e .atualiza.sh em crontab.json
- F03 (mensagem de erro exata): Error deleting rule (Operation not permitted) / There was an error while processing parameters
- Quedas da sessão SSH (quando e em qual terminal): nenhuma

## Coleta e análise
- SHA-256 do coleta_vitima.tar.gz (na VM / no Mint): ef8de2cc...ca56438 nos dois (idênticos; completar com o valor inteiro do arquivo coleta_vitima.tar.gz.sha256); 185 arquivos conferidos pelo hashes.sha256 sem divergência
- Tempo do aide --check na coleta: 16,740 s; código de saída 5 (entradas adicionadas e modificadas); 40.597 entradas, 16 adicionadas, 0 removidas, 25 modificadas (6 não relacionadas ao cenário: 99-imutavel.rules, audit.rules, audit.rules.prev, /etc/audit/rules.d, /root e audit.log)
- Tempo do log2timeline: 12,784 s (Plaso 20261027 em Docker, imagem vitima_final.raw do snapshot final, filtro de diretórios); 18.649 eventos; nenhum interpretador para o audit.log
- Osquery "depois": 3,105 s
- Super timeline: 2.221 eventos no intervalo do cenário (1.659 auditd, 522 Plaso, 40 Osquery)
- Ajustes que precisei fazer em scripts ou comandos: comum.sh (LC_NUMERIC=C e soma de audit.log*); 00_preparar reinicia o auditd após configurar a rotação e desativa o dailyaidecheck.timer; 04_coletar grava o pacote na home do pesquisador mesmo com sudo -i encadeado; volume_por_fase.py e mesclar_timeline.py ganharam a opção --excluir-janela (usada para o X01)
- Impressão sobre a timeline (o que foi fácil e difícil de ligar entre as fontes): fácil ligar auditd, journal e metadados de arquivos quando caem no mesmo segundo da ação (ex.: D04: comando no journal, criação do arquivo no auditd, nascimento do arquivo no fs:stat, conteúdo da regra no Osquery). Difícil: o Plaso não lê o audit.log (precisou de normalização própria), fusos diferentes (auth.log em horário local, auditd em época), resolução de 1 s no Plaso, eventos duplicados entre auth.log e journal, e eventos de processos do sistema (dhcpcd) caindo dentro da janela de uma ação
- Outras observações e dificuldades:
  - O F02 (sed -i) trocou o inode do auth.log; o rsyslog continuou escrevendo no arquivo antigo, então nada depois do F02 entrou no auth.log (F03 e F05 ausentes). O syslog continuou normal.
  - O journal do systemd guardou tudo o que o F02 apagou do auth.log (useradd, usermod, comandos do D04 e D05, o próprio sed e o auditctl -D).
  - O .bash_history do alvo terminou só com "exit" (efeito do F04).
  - O AIDE não viu /tmp/backdoor.sh nem /tmp/.exf (criados e apagados entre a base e a verificação).
  - Consulta do Osquery em ~/.cache voltou vazia nas três capturas (o padrão % não pega nomes começando com ponto).
  - O ss do A07 carregou os módulos inet_diag, tcp_diag e udp_diag (vistos no auditd e no Osquery).
  - O find do A08 gerou 835 eventos de acesso negado; a fase de reconhecimento concentrou 68% dos eventos do auditd do cenário.

## Resultados principais (para o Capítulo 4)
- Volume do cenário (sem pesquisador e sem a janela do X01): 1.624 eventos do auditd (1.499.291 bytes, 923 bytes por evento), 31 linhas do auth.log e 70 do syslog, em 2.001 s
- Volume total no fim do experimento: audit.log 73.068.339 bytes (54.756 eventos, maior parte da medição de overhead); auth.log 6.938 bytes; syslog 82.974 bytes
- Cobertura isolada: auditd 98,5% (33 Sim, 1 Parcial); journal 35,3%; AIDE 32,4%; Osquery 25,0%; rsyslog 22,1%; histórico 4,4%
- Conjunto mínimo: auditd sozinho (98,5%); sem auditd, melhor combinação journal + AIDE + Osquery = 55,9%, com 12 ações sem nenhum registro
- Única ação sem registro completo em nenhuma fonte: F04 (history é comando interno do shell)
## Verificações posteriores (12/11/2026)
- Arquivos do auditd na coleta: audit.log (38.844.680 bytes, inicia em 01:24:27 UTC, contém todo o cenário) e audit.log.1 a .4 (cerca de 8 MiB cada, rotacionados às 01:24 UTC durante a 1ª medição de overhead, descartada). Não houve rotação depois do ajuste para 50 MiB.
- Teste do Plaso 20261027 com --parsers text/selinux: audit.log original (formato ENRICHED, com caractere 0x1d) gerou 0 eventos; a mesma cópia com 0x1d trocado por espaço gerou 199.229 eventos. Confirma que o analisador de texto descarta o arquivo como binário por causa do 0x1d.
