# Roteiro do experimento (referência rápida de comandos)

O passo a passo completo, com o que conferir e o que anotar, está no **Guia de execução do experimento (TCC2)**. Este arquivo reúne apenas os comandos, na ordem, para consulta rápida.

Convenções:

- Hospedeiro: Linux Mint. Todos os comandos do hospedeiro rodam na pasta onde este pacote foi extraído (ex.: `~/tcc-experimento`).
- Vítima: Debian 13 no VirtualBox, executada sem interface gráfica (*headless*). Toda interação é por SSH.
- Duas contas na vítima: `pesquisador` (administração, preparação e coleta) e `alvo` (somente o atacante simulado).
- IP fixo da vítima na rede host-only: `192.168.56.10`. IP do hospedeiro: `192.168.56.1`.
- Horários sempre em UTC.

## 1. Hospedeiro (uma vez)

```bash
grep -c -e vmx -e svm /proc/cpuinfo           # precisa ser maior que 0
sudo apt update
sudo apt install -y virtualbox openssh-client python3 netcat-openbsd curl docker.io
sudo usermod -aG vboxusers,docker $USER        # depois saia da sessão e entre de novo
VBoxManage --version
docker pull log2timeline/plaso
ssh-keygen -t ed25519 -f chave_teste_tcc -N "" -C teste-tcc   # chave usada na ação B03
```

## 2. VirtualBox

```bash
VBoxManage list hostonlyifs | grep -E "Name|IPAddress"   # deve existir vboxnet0 com 192.168.56.1
VBoxManage hostonlyif create                              # só se não existir
VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1 --netmask 255.255.255.0
```

Crie a VM `tcc-vitima` pela interface do VirtualBox: Debian 64-bit, 2 CPUs, 2048 MB, disco VDI de 20 GB, Adaptador 1 = NAT, Adaptador 2 = Placa de rede exclusiva de hospedeiro (`vboxnet0`).

## 3. Debian (única vez em que se usa a janela da VM)

Na instalação: nome `vitima`; defina senha de root; primeiro usuário `pesquisador`; software apenas **servidor SSH** e **utilitários padrão do sistema**.

Após o primeiro boot, no console, como root:

```bash
apt install -y sudo systemd-timesyncd
usermod -aG sudo pesquisador
adduser alvo && usermod -aG sudo alvo
ip -br link                                   # anote o nome da 2ª interface (ex.: enp0s8)
cat >> /etc/network/interfaces <<'CFG'

allow-hotplug enp0s8
iface enp0s8 inet static
    address 192.168.56.10/24
CFG
ifup enp0s8 && ip -br addr
```

No hospedeiro:

```bash
ssh-copy-id pesquisador@192.168.56.10          # só para o pesquisador; o alvo entra com senha
ssh pesquisador@192.168.56.10 'id; timedatectl | grep synchronized'
ssh alvo@192.168.56.10 'id' 
```

Desligue e preserve a imagem original (antes de qualquer snapshot):

```bash
ssh pesquisador@192.168.56.10 'sudo poweroff'
VBoxManage showvminfo tcc-vitima --machinereadable | grep -i '\.vdi'
VBoxManage clonemedium disk "<caminho do .vdi>" vitima_original.vdi
sha256sum vitima_original.vdi | tee vitima_original.vdi.sha256
VBoxManage startvm tcc-vitima --type headless
cd hospedeiro && ./snapshot_vm.sh 00-instalacao-limpa && cd ..
```

## 4. Preparação dos mecanismos (sessão do pesquisador)

```bash
scp -r vitima pesquisador@192.168.56.10:~/tcc-scripts
ssh pesquisador@192.168.56.10
sudo -i
mv /home/pesquisador/tcc-scripts /root/tcc-scripts && cd /root/tcc-scripts && chmod +x *.sh
./00_preparar.sh
```

Snapshot no hospedeiro: `./snapshot_vm.sh 01-ferramentas`.

Os próximos scripts são longos; rode-os dentro do `tmux` (instalado pelo `00_preparar.sh`) para não perder a execução se o SSH cair:

```bash
tmux new -s tcc          # para sair sem interromper: Ctrl+B e depois D; para voltar: tmux attach -t tcc
cd /root/tcc-scripts
./01_medir_overhead.sh 5000 5
./02_medir_ruido.sh 60
./03_baseline.sh
```

Snapshot no hospedeiro: `./snapshot_vm.sh 02-baseline`.

## 5. Cenário

Terminais no hospedeiro:

| Terminal | Uso |
|---|---|
| A | `ssh alvo@192.168.56.10` (só comandos do plano) |
| B | `cd hospedeiro && ./registrar_acao.sh <ID>` antes de cada ação |
| C | `cd hospedeiro && ./servir_ferramenta.sh` (deixar rodando) |
| D | `cd hospedeiro`: snapshots e `./receber_exfiltracao.sh` |
| E | sessão do pesquisador (`sudo -i`), parada, usada só no X01 |

Ciclo de cada ação: registrar no B, digitar no A, esperar terminar, aguardar cerca de 10 segundos.

As fases não recebem snapshot próprio (a separação é feita pelos horários do gabarito). Antes do E04: `./receber_exfiltracao.sh` no D. No X01: registrar no B e rodar no E `/root/tcc-scripts/snapshot_osquery.sh durante`. Após o F05: rode `sync` no E e então `./snapshot_vm.sh final` no D.

## 6. Coleta

No terminal E (pesquisador, root):

```bash
cd /root/tcc-scripts && ./04_coletar.sh
```

No hospedeiro:

```bash
scp pesquisador@192.168.56.10:coleta_vitima.tar.gz .
sha256sum coleta_vitima.tar.gz && tar xzf coleta_vitima.tar.gz
cat coleta/contas.txt        # anote uid_pesquisador
```

## 7. Análise

Substitua `UID_P` pelo `uid_pesquisador` de `coleta/contas.txt`.

```bash
python3 analise/montar_gabarito.py hospedeiro/plano_acoes.tsv hospedeiro/execucao.csv gabarito.csv
python3 analise/normalizar_auditd.py coleta/logs/audit/audit.log audit_eventos.csv
python3 analise/diff_osquery.py coleta/osquery osquery_diff.csv
python3 analise/volume_por_fase.py gabarito.csv coleta/logs/audit/audit.log coleta/logs/auth.log coleta/logs/syslog \
    volume_por_fase.csv --excluir-auid UID_P --excluir-usuario pesquisador
```

Se algum comando de coleta tiver sido digitado por engano na sessão do `alvo`, acrescente `--excluir-janela INICIO FIM` (UTC, ISO) aqui e no `mesclar_timeline.py`.

Plaso (VM desligada, no estado do snapshot `final`):

```bash
VBoxManage controlvm tcc-vitima acpipowerbutton      # aguarde desligar
VBoxManage snapshot tcc-vitima restore final
VBoxManage showvminfo tcc-vitima --machinereadable | grep -i '\.vdi'
VBoxManage clonemedium disk "<disco atual>.vdi" vitima_final.raw --format RAW
cd hospedeiro && ./timeline_plaso.sh ../vitima_final.raw && cd ..
python3 analise/mesclar_timeline.py gabarito.csv super_timeline.csv \
    --plaso hospedeiro/plaso/timeline_plaso.csv --extra audit_eventos.csv osquery_diff.csv \
    --excluir-auid UID_P --excluir-usuario pesquisador
```

## 8. Envio

```bash
bash analise/montar_envio.sh
```

Envie o `envio_tcc.zip` na conversa. Não envie imagens de disco, logs brutos completos nem a chave privada `chave_teste_tcc`.
