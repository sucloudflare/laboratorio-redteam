#!/usr/bin/env bash
# =============================================================================
#  RED TEAM LAB — Setup Automático Completo
#  Versão: 2.0
#  Compatível: Ubuntu 22.04 LTS / Kali Linux 2024.x
# =============================================================================
# USO:
#   sudo ./setup.sh            → instala tudo
#   sudo ./setup.sh --kali     → apenas configura ferramentas (dentro do Kali)
#   sudo ./setup.sh --host     → apenas configura o host (VirtualBox, Vagrant)
#   sudo ./setup.sh --android  → apenas ambiente Android
#   sudo ./setup.sh --reset    → reseta lab para estado limpo
# =============================================================================

set -euo pipefail

# ─── Cores ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ─── Variáveis globais ────────────────────────────────────────────────────────
LAB_DIR="$HOME/redteam-lab"
KALI_IP="192.168.56.10"
META_IP="192.168.56.20"
ANDROID_IP="192.168.56.22"
HOST_ONLY_NET="192.168.56.0/24"
VBOX_NETNAME="redteam-hostonly"
LOG_FILE="/tmp/redteam-lab-setup.log"
MODE="${1:-}"

# ─── Banner ───────────────────────────────────────────────────────────────────
banner() {
cat << 'EOF'

  ██████╗ ███████╗██████╗     ████████╗███████╗ █████╗ ███╗   ███╗    ██╗      █████╗ ██████╗
  ██╔══██╗██╔════╝██╔══██╗    ╚══██╔══╝██╔════╝██╔══██╗████╗ ████║    ██║     ██╔══██╗██╔══██╗
  ██████╔╝█████╗  ██║  ██║       ██║   █████╗  ███████║██╔████╔██║    ██║     ███████║██████╔╝
  ██╔══██╗██╔══╝  ██║  ██║       ██║   ██╔══╝  ██╔══██║██║╚██╔╝██║    ██║     ██╔══██║██╔══██╗
  ██║  ██║███████╗██████╔╝       ██║   ███████╗██║  ██║██║ ╚═╝ ██║    ███████╗██║  ██║██████╔╝
  ╚═╝  ╚═╝╚══════╝╚═════╝        ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝    ╚══════╝╚═╝  ╚═╝╚═════╝

                    🔴  Ambiente Red Team — Setup Automático  🔴
                         Apenas para fins educacionais
EOF
echo ""
}

# ─── Funções utilitárias ──────────────────────────────────────────────────────
log()     { echo -e "${GREEN}[+]${NC} $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE"; exit 1; }
info()    { echo -e "${BLUE}[i]${NC} $*" | tee -a "$LOG_FILE"; }
step()    { echo -e "\n${BOLD}${CYAN}══ $* ══${NC}" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[✓]${NC} $*" | tee -a "$LOG_FILE"; }

check_root() {
    [[ $EUID -ne 0 ]] && error "Execute como root: sudo $0 $*"
}

check_os() {
    if grep -qi "kali" /etc/os-release 2>/dev/null; then
        echo "kali"
    elif grep -qi "ubuntu\|debian" /etc/os-release 2>/dev/null; then
        echo "ubuntu"
    else
        echo "unknown"
    fi
}

cmd_exists() { command -v "$1" &>/dev/null; }

apt_install() {
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        >> "$LOG_FILE" 2>&1
}

spinner() {
    local pid=$!
    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}%s${NC} %s" "${spin[$i]}" "$1"
        i=$(( (i+1) % 10 ))
        sleep 0.1
    done
    printf "\r  ${GREEN}✓${NC} %-50s\n" "$1"
}

# ─── 1. Verificar pré-requisitos do host ─────────────────────────────────────
check_host_requirements() {
    step "Verificando pré-requisitos do host"

    # VT-x / AMD-V
    if grep -qE 'vmx|svm' /proc/cpuinfo; then
        success "Virtualização de hardware habilitada"
    else
        warn "VT-x/AMD-V não detectado. Habilite na BIOS para melhor desempenho."
    fi

    # RAM
    local ram_gb
    ram_gb=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024 ))
    if [[ $ram_gb -ge 8 ]]; then
        success "RAM: ${ram_gb}GB (OK)"
    else
        warn "RAM: ${ram_gb}GB. Recomendado: 16GB+"
    fi

    # Disco
    local disk_gb
    disk_gb=$(df -BG "$HOME" | awk 'NR==2{print $4}' | tr -d 'G')
    if [[ $disk_gb -ge 60 ]]; then
        success "Espaço livre: ${disk_gb}GB (OK)"
    else
        error "Espaço livre: ${disk_gb}GB. Mínimo: 80GB"
    fi
}

# ─── 2. Instalar dependências do host ─────────────────────────────────────────
install_host_dependencies() {
    step "Instalando dependências base"

    apt-get update -qq >> "$LOG_FILE" 2>&1
    apt_install curl wget git unzip gnupg2 ca-certificates \
        apt-transport-https software-properties-common lsb-release

    # VirtualBox
    if ! cmd_exists VBoxManage; then
        log "Instalando VirtualBox..."
        wget -qO- https://www.virtualbox.org/download/oracle_vbox_2016.asc \
            | gpg --dearmor > /usr/share/keyrings/virtualbox.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/virtualbox.gpg] \
https://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" \
            > /etc/apt/sources.list.d/virtualbox.list
        apt-get update -qq >> "$LOG_FILE" 2>&1
        apt_install virtualbox-7.0
        success "VirtualBox instalado"
    else
        success "VirtualBox já instalado: $(VBoxManage --version)"
    fi

    # Vagrant
    if ! cmd_exists vagrant; then
        log "Instalando Vagrant..."
        wget -qO /tmp/vagrant.deb \
            https://releases.hashicorp.com/vagrant/2.4.1/vagrant_2.4.1-1_amd64.deb
        dpkg -i /tmp/vagrant.deb >> "$LOG_FILE" 2>&1
        rm -f /tmp/vagrant.deb
        success "Vagrant instalado"
    else
        success "Vagrant já instalado: $(vagrant --version)"
    fi

    # Docker (host)
    if ! cmd_exists docker; then
        log "Instalando Docker no host..."
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
            | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
            > /etc/apt/sources.list.d/docker.list
        apt-get update -qq >> "$LOG_FILE" 2>&1
        apt_install docker-ce docker-ce-cli containerd.io docker-compose-plugin
        usermod -aG docker "$SUDO_USER"
        systemctl enable --now docker
        success "Docker instalado"
    else
        success "Docker já instalado: $(docker --version)"
    fi
}

# ─── 3. Configurar rede VirtualBox ────────────────────────────────────────────
setup_virtualbox_network() {
    step "Configurando rede Host-Only do VirtualBox"

    # Verificar se já existe
    if VBoxManage list hostonlyifs | grep -q "192.168.56"; then
        success "Rede Host-Only já configurada"
        return
    fi

    local ifname
    ifname=$(VBoxManage hostonlyif create 2>&1 | grep -oP "(?<=Interface ').*(?=')")
    VBoxManage hostonlyif ipconfig "$ifname" \
        --ip 192.168.56.1 --netmask 255.255.255.0
    VBoxManage dhcpserver add --ifname "$ifname" \
        --ip 192.168.56.100 --netmask 255.255.255.0 \
        --lowerip 192.168.56.101 --upperip 192.168.56.200 --enable \
        >> "$LOG_FILE" 2>&1 || true

    success "Rede Host-Only criada: 192.168.56.0/24 (interface: $ifname)"
}

# ─── 4. Instalar Kali Linux ───────────────────────────────────────────────────
setup_kali_vm() {
    step "Configurando VM Kali Linux"

    local kali_dir="$LAB_DIR/kali-vm"
    mkdir -p "$kali_dir"

    if VBoxManage list vms | grep -q "Kali-RedTeam"; then
        warn "VM Kali-RedTeam já existe. Pulando criação."
        return
    fi

    log "Baixando Kali Linux via Vagrant box..."
    cat > "$kali_dir/Vagrantfile" << 'VAGRANTFILE'
Vagrant.configure("2") do |config|
  config.vm.box = "kalilinux/rolling"
  config.vm.box_check_update = false
  config.vm.hostname = "kali-redteam"
  config.vm.network "private_network", ip: "192.168.56.10"

  config.vm.provider "virtualbox" do |vb|
    vb.name = "Kali-RedTeam"
    vb.memory = 4096
    vb.cpus = 2
    vb.gui = false
    vb.customize ["modifyvm", :id, "--vram", "64"]
    vb.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
  end

  config.vm.provision "shell", path: "../scripts/kali-provision.sh"
end
VAGRANTFILE

    cd "$kali_dir"
    vagrant up --provision >> "$LOG_FILE" 2>&1 &
    spinner "Baixando e configurando Kali Linux (pode demorar ~15 min)"

    # Snapshot do estado limpo
    vagrant snapshot save clean-state >> "$LOG_FILE" 2>&1 || true
    success "VM Kali Linux criada e configurada"
}

# ─── 5. Instalar Metasploitable3 ─────────────────────────────────────────────
setup_metasploitable3() {
    step "Configurando Metasploitable3 (alvo Linux)"

    local meta_dir="$LAB_DIR/metasploitable3"
    mkdir -p "$meta_dir"

    if VBoxManage list vms | grep -q "Metasploitable3"; then
        warn "Metasploitable3 já existe. Pulando."
        return
    fi

    cat > "$meta_dir/Vagrantfile" << 'VAGRANTFILE'
Vagrant.configure("2") do |config|
  config.vm.define "metasploitable3-ub1404" do |v|
    v.vm.box = "rapid7/metasploitable3-ub1404"
    v.vm.hostname = "metasploitable3"
    v.vm.network "private_network", ip: "192.168.56.20"

    v.vm.provider "virtualbox" do |vb|
      vb.name = "Metasploitable3"
      vb.memory = 2048
      vb.cpus = 1
    end
  end
end
VAGRANTFILE

    cd "$meta_dir"
    vagrant up >> "$LOG_FILE" 2>&1 &
    spinner "Baixando Metasploitable3 (~2GB, pode demorar)"

    vagrant snapshot save clean-state >> "$LOG_FILE" 2>&1 || true
    success "Metasploitable3 pronto em 192.168.56.20"
}

# ─── 6. Provisionar ferramentas no Kali ──────────────────────────────────────
provision_kali_tools() {
    step "Instalando ferramentas red team no Kali"

    local OS
    OS=$(check_os)

    # Atualizar repos
    log "Atualizando pacotes..."
    apt-get update -qq >> "$LOG_FILE" 2>&1
    apt-get upgrade -y -qq >> "$LOG_FILE" 2>&1

    # ── Ferramentas de reconhecimento ──
    log "Instalando ferramentas de reconhecimento..."
    apt_install nmap masscan netdiscover enum4linux enum4linux-ng \
        dnsutils whois dnsx subfinder amass \
        smbclient smbmap nbtscan

    # ── Ferramentas web ──
    log "Instalando ferramentas web..."
    apt_install burpsuite nikto gobuster ffuf wfuzz \
        sqlmap whatweb wafw00f dirb dirbuster \
        curl wget httpie

    # ── Metasploit Framework ──
    if ! cmd_exists msfconsole; then
        log "Instalando Metasploit Framework..."
        curl -fsSL https://apt.metasploit.com/metasploit-framework.gpg.key \
            | gpg --dearmor > /usr/share/keyrings/metasploit.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/metasploit.gpg] \
https://apt.metasploit.com/ buster main" \
            > /etc/apt/sources.list.d/metasploit.list
        apt-get update -qq >> "$LOG_FILE" 2>&1
        apt_install metasploit-framework
        msfdb init >> "$LOG_FILE" 2>&1 || true
        success "Metasploit instalado"
    else
        success "Metasploit já instalado"
    fi

    # ── Exploit-DB / SearchSploit ──
    apt_install exploitdb

    # ── Cracking de senhas ──
    log "Instalando ferramentas de cracking..."
    apt_install john johntheripper-data hashcat hydra medusa crowbar \
        wordlists

    # Descompactar rockyou
    if [[ -f /usr/share/wordlists/rockyou.txt.gz ]]; then
        gunzip /usr/share/wordlists/rockyou.txt.gz 2>/dev/null || true
    fi

    # ── Análise de rede ──
    log "Instalando ferramentas de rede..."
    apt_install wireshark tcpdump bettercap responder \
        proxychains4 socat netcat-openbsd

    # ── Post-exploitation ──
    apt_install bloodhound neo4j powershell-empire impacket-scripts

    # ── Docker + Docker Compose ──
    if ! cmd_exists docker; then
        log "Instalando Docker..."
        apt_install docker.io docker-compose
        systemctl enable --now docker
        usermod -aG docker kali 2>/dev/null || true
        success "Docker instalado"
    fi

    # ── Vulhub ──
    if [[ ! -d /home/kali/vulhub ]]; then
        log "Clonando Vulhub..."
        git clone --depth=1 https://github.com/vulhub/vulhub.git \
            /home/kali/vulhub >> "$LOG_FILE" 2>&1
        chown -R kali:kali /home/kali/vulhub
        success "Vulhub clonado: $(ls /home/kali/vulhub | wc -l) categorias disponíveis"
    else
        log "Atualizando Vulhub..."
        git -C /home/kali/vulhub pull --quiet >> "$LOG_FILE" 2>&1 || true
        success "Vulhub atualizado"
    fi

    # ── DVWA ──
    setup_dvwa

    # ── OpenVAS / Greenbone ──
    setup_openvas

    # ── Python tools ──
    log "Instalando ferramentas Python..."
    pip3 install --quiet --break-system-packages \
        impacket scapy pwntools requests \
        colorama tabulate 2>/dev/null || \
    pip3 install --quiet \
        impacket scapy pwntools requests \
        colorama tabulate 2>/dev/null || true

    # ── Tmux config ──
    setup_tmux_config

    success "Todas as ferramentas instaladas!"
}

# ─── 7. DVWA ──────────────────────────────────────────────────────────────────
setup_dvwa() {
    step "Configurando DVWA (Damn Vulnerable Web Application)"

    if docker ps -a | grep -q dvwa; then
        warn "DVWA já está configurado"
        return
    fi

    cat > /home/kali/dvwa-compose.yml << 'COMPOSE'
version: '3'
services:
  dvwa:
    image: vulnerables/web-dvwa
    ports:
      - "8888:80"
    restart: unless-stopped
    environment:
      - MYSQL_PASS=p@ssw0rd
COMPOSE

    docker-compose -f /home/kali/dvwa-compose.yml up -d >> "$LOG_FILE" 2>&1
    chown kali:kali /home/kali/dvwa-compose.yml
    success "DVWA rodando em http://127.0.0.1:8888 (admin/password)"
}

# ─── 8. OpenVAS ───────────────────────────────────────────────────────────────
setup_openvas() {
    step "Instalando OpenVAS / Greenbone"

    if cmd_exists gvm-start; then
        warn "OpenVAS já instalado"
        return
    fi

    apt_install gvm 2>/dev/null || apt_install openvas 2>/dev/null || {
        warn "OpenVAS não disponível via apt. Instalando via script oficial..."
        curl -fsSL https://greenbone.net/install.sh | bash >> "$LOG_FILE" 2>&1 || true
        return
    }

    log "Inicializando banco de dados OpenVAS (pode demorar ~10 min)..."
    gvm-setup >> "$LOG_FILE" 2>&1 || true
    gvm-check-setup >> "$LOG_FILE" 2>&1 || true

    # Salvar senha gerada
    local gvm_pass
    gvm_pass=$(grep -oP "(?<=password: ).*" "$LOG_FILE" | tail -1 || echo "ver log")
    echo "OpenVAS admin password: $gvm_pass" > /home/kali/CREDENCIAIS-LAB.txt
    chown kali:kali /home/kali/CREDENCIAIS-LAB.txt
    success "OpenVAS instalado. Acesse: https://127.0.0.1:9392"
}

# ─── 9. Ambiente Android ──────────────────────────────────────────────────────
setup_android_lab() {
    step "Configurando laboratório Android"

    # ADB
    apt_install adb

    # APKTool
    if ! cmd_exists apktool; then
        log "Instalando APKTool..."
        wget -qO /usr/local/bin/apktool \
            https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool
        wget -qO /usr/local/bin/apktool.jar \
            "$(curl -s https://api.github.com/repos/iBotPeaches/Apktool/releases/latest \
            | grep browser_download_url | grep '.jar' | cut -d '"' -f 4)"
        chmod +x /usr/local/bin/apktool
        success "APKTool instalado"
    fi

    # JADX
    if ! cmd_exists jadx; then
        log "Instalando JADX..."
        local jadx_url
        jadx_url=$(curl -s https://api.github.com/repos/skylot/jadx/releases/latest \
            | grep browser_download_url | grep "jadx-[0-9].*zip" \
            | head -1 | cut -d '"' -f 4)
        wget -qO /tmp/jadx.zip "$jadx_url"
        unzip -q /tmp/jadx.zip -d /opt/jadx
        ln -sf /opt/jadx/bin/jadx /usr/local/bin/jadx
        rm -f /tmp/jadx.zip
        success "JADX instalado"
    fi

    # Frida
    log "Instalando Frida e Objection..."
    pip3 install --quiet --break-system-packages frida-tools objection 2>/dev/null || \
    pip3 install --quiet frida-tools objection 2>/dev/null || true

    # MobSF
    if [[ ! -d /opt/MobSF ]]; then
        log "Instalando MobSF..."
        apt_install python3-pip python3-venv openjdk-17-jdk \
            libssl-dev libffi-dev libxml2-dev libxslt1-dev zlib1g-dev \
            wkhtmltopdf
        git clone --depth=1 https://github.com/MobSF/Mobile-Security-Framework-MobSF.git \
            /opt/MobSF >> "$LOG_FILE" 2>&1
        cd /opt/MobSF
        python3 -m venv venv
        venv/bin/pip install --quiet -r requirements.txt
        chmod +x setup.sh run.sh
        chown -R kali:kali /opt/MobSF
        success "MobSF instalado. Iniciar: cd /opt/MobSF && ./run.sh 0.0.0.0:8000"
    fi

    # APPs vulneráveis para Android
    local android_dir="/home/kali/android-labs"
    mkdir -p "$android_dir"

    log "Baixando APPs vulneráveis..."

    # DIVA APK
    [[ ! -f "$android_dir/diva.apk" ]] && \
        wget -qO "$android_dir/diva.apk" \
        "https://github.com/payatu/diva-android/raw/master/DivaApplication.apk" \
        2>/dev/null || warn "DIVA: baixar manualmente de github.com/payatu/diva-android"

    # InsecureBankv2
    if [[ ! -d "$android_dir/InsecureBankv2" ]]; then
        git clone --depth=1 https://github.com/dineshshetty/Android-InsecureBankv2.git \
            "$android_dir/InsecureBankv2" >> "$LOG_FILE" 2>&1 || true
    fi

    # InjuredAndroid
    [[ ! -f "$android_dir/injuredandroid.apk" ]] && \
        wget -qO "$android_dir/injuredandroid.apk" \
        "https://github.com/B3nac/InjuredAndroid/releases/latest/download/injuredandroid.apk" \
        2>/dev/null || warn "InjuredAndroid: baixar de github.com/B3nac/InjuredAndroid"

    chown -R kali:kali "$android_dir"

    # Script helper Android
    cat > /usr/local/bin/android-lab << 'ANDROID_SCRIPT'
#!/usr/bin/env bash
# Android Lab Helper

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
ANDROID_DIR="/home/kali/android-labs"

case "${1:-help}" in
    devices)  adb devices -l ;;
    shell)    adb shell ;;
    frida-server)
        echo -e "${CYAN}[*] Enviando Frida Server para o emulador...${NC}"
        FRIDA_VER=$(frida --version 2>/dev/null || echo "16.2.1")
        ARCH=$(adb shell getprop ro.product.cpu.abi | tr -d '\r')
        URL="https://github.com/frida/frida/releases/download/${FRIDA_VER}/frida-server-${FRIDA_VER}-android-${ARCH}.xz"
        wget -qO /tmp/frida-server.xz "$URL"
        unxz /tmp/frida-server.xz
        adb push /tmp/frida-server /data/local/tmp/frida-server
        adb shell "chmod 755 /data/local/tmp/frida-server"
        adb shell "/data/local/tmp/frida-server &"
        echo -e "${GREEN}[✓] Frida Server rodando!${NC}"
        ;;
    install-apps)
        echo -e "${CYAN}[*] Instalando APPs vulneráveis...${NC}"
        for apk in "$ANDROID_DIR"/*.apk; do
            echo -e "  → Instalando: $(basename $apk)"
            adb install -r "$apk" 2>/dev/null || true
        done
        echo -e "${GREEN}[✓] APPs instaladas!${NC}"
        ;;
    mobsf)
        echo -e "${CYAN}[*] Iniciando MobSF em http://0.0.0.0:8000${NC}"
        cd /opt/MobSF && ./run.sh 0.0.0.0:8000
        ;;
    bypass-ssl)
        PACKAGE="${2:-}"
        [[ -z "$PACKAGE" ]] && { echo "Uso: android-lab bypass-ssl <package>"; exit 1; }
        echo -e "${CYAN}[*] Iniciando bypass SSL Pinning em $PACKAGE${NC}"
        objection -g "$PACKAGE" explore --startup-command "android sslpinning disable"
        ;;
    *)
        echo -e "${CYAN}Android Lab Helper${NC}"
        echo "  devices        → listar dispositivos"
        echo "  shell          → shell ADB"
        echo "  frida-server   → iniciar Frida Server no emulador"
        echo "  install-apps   → instalar APPs vulneráveis"
        echo "  mobsf          → iniciar MobSF"
        echo "  bypass-ssl <pkg> → bypass SSL Pinning com Objection"
        ;;
esac
ANDROID_SCRIPT
    chmod +x /usr/local/bin/android-lab
    success "Laboratório Android configurado"
}

# ─── 10. Vulhub Helper ────────────────────────────────────────────────────────
create_vulhub_helper() {
    step "Criando Vulhub Helper"

    cat > /usr/local/bin/vulhub << 'VULHUB_SCRIPT'
#!/usr/bin/env bash
# Vulhub Helper — Gerenciar ambientes CVE

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
VULHUB_DIR="/home/kali/vulhub"
ACTIVE_LOG="/tmp/vulhub-active.txt"
touch "$ACTIVE_LOG"

case "${1:-help}" in
    list)
        FILTER="${2:-}"
        echo -e "${BOLD}${CYAN}CVEs disponíveis no Vulhub:${NC}"
        count=0
        for path in "$VULHUB_DIR"/*/CVE-*; do
            [[ -f "$path/docker-compose.yml" ]] || continue
            rel="${path#$VULHUB_DIR/}"
            [[ -n "$FILTER" && "$rel" != *"$FILTER"* ]] && continue
            printf "  %-45s" "$rel"
            count=$((count+1))
            [[ $((count % 2)) -eq 0 ]] && echo "" || printf ""
        done
        echo ""
        echo -e "${GREEN}Total: $count CVEs${NC}"
        ;;
    start)
        CVE="${2:-}"
        [[ -z "$CVE" ]] && { echo "Uso: vulhub start <app/CVE-XXXX-XXXX>"; exit 1; }
        CVE_PATH="$VULHUB_DIR/$CVE"
        [[ ! -d "$CVE_PATH" ]] && { echo -e "${RED}CVE não encontrado: $CVE${NC}"; exit 1; }
        echo -e "${CYAN}[*] Subindo: $CVE${NC}"
        cd "$CVE_PATH"
        docker-compose up -d
        echo "$CVE" >> "$ACTIVE_LOG"
        echo ""
        echo -e "${GREEN}[✓] Ambiente pronto!${NC}"
        echo -e "${YELLOW}[i] Portas mapeadas:${NC}"
        docker-compose ps
        echo ""
        echo -e "${YELLOW}[i] Para parar: vulhub stop $CVE${NC}"
        ;;
    stop)
        CVE="${2:-}"
        [[ -z "$CVE" ]] && { echo "Uso: vulhub stop <app/CVE-XXXX-XXXX>"; exit 1; }
        CVE_PATH="$VULHUB_DIR/$CVE"
        echo -e "${CYAN}[*] Parando: $CVE${NC}"
        cd "$CVE_PATH"
        docker-compose down -v
        sed -i "/$CVE/d" "$ACTIVE_LOG" 2>/dev/null || true
        echo -e "${GREEN}[✓] Ambiente removido${NC}"
        ;;
    status)
        echo -e "${BOLD}${CYAN}Containers Vulhub ativos:${NC}"
        docker ps --filter "label=com.docker.compose.project" \
            --format "  {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null \
            || echo "  Nenhum container ativo"
        ;;
    reset)
        echo -e "${YELLOW}[!] Parando TODOS os containers Vulhub...${NC}"
        while IFS= read -r cve; do
            [[ -z "$cve" ]] && continue
            echo -e "  → Parando $cve"
            cd "$VULHUB_DIR/$cve" && docker-compose down -v 2>/dev/null || true
        done < "$ACTIVE_LOG"
        > "$ACTIVE_LOG"
        echo -e "${GREEN}[✓] Todos os ambientes parados${NC}"
        ;;
    update)
        echo -e "${CYAN}[*] Atualizando Vulhub...${NC}"
        git -C "$VULHUB_DIR" pull
        echo -e "${GREEN}[✓] Vulhub atualizado${NC}"
        ;;
    help|*)
        echo -e "${BOLD}${CYAN}Vulhub Helper${NC} — Gerenciar ambientes CVE"
        echo ""
        echo -e "  ${GREEN}vulhub list [filtro]${NC}          → listar CVEs disponíveis"
        echo -e "  ${GREEN}vulhub start <app/CVE>  ${NC}      → subir ambiente vulnerável"
        echo -e "  ${GREEN}vulhub stop  <app/CVE>  ${NC}      → parar e limpar ambiente"
        echo -e "  ${GREEN}vulhub status           ${NC}      → ver containers ativos"
        echo -e "  ${GREEN}vulhub reset            ${NC}      → parar TODOS os containers"
        echo -e "  ${GREEN}vulhub update           ${NC}      → atualizar repositório"
        echo ""
        echo -e "Exemplo:"
        echo -e "  vulhub start log4j/CVE-2021-44228"
        echo -e "  vulhub list struts"
        ;;
esac
VULHUB_SCRIPT

    chmod +x /usr/local/bin/vulhub
    success "vulhub helper instalado. Use: vulhub help"
}

# ─── 11. Script de reset do lab ───────────────────────────────────────────────
create_reset_script() {
    cat > /usr/local/bin/lab-reset << 'RESET_SCRIPT'
#!/usr/bin/env bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${YELLOW}[!] Resetando laboratório para estado limpo...${NC}"

# Parar containers Docker
echo -e "  → Parando todos os containers..."
docker stop $(docker ps -q) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# Limpar redes Docker
docker network prune -f 2>/dev/null || true

# Reiniciar DVWA
echo -e "  → Reiniciando DVWA..."
docker-compose -f /home/kali/dvwa-compose.yml up -d 2>/dev/null || true

# Limpar logs temporários
rm -f /tmp/vulhub-active.txt
touch /tmp/vulhub-active.txt

echo -e "${GREEN}[✓] Lab resetado! Pronto para nova sessão.${NC}"
echo -e "    DVWA:    http://127.0.0.1:8888"
echo -e "    OpenVAS: https://127.0.0.1:9392"
RESET_SCRIPT
    chmod +x /usr/local/bin/lab-reset
}

# ─── 12. Tmux config ──────────────────────────────────────────────────────────
setup_tmux_config() {
    cat > /home/kali/.tmux.conf << 'TMUX'
set -g prefix C-a
unbind C-b
bind C-a send-prefix
set -g mouse on
set -g history-limit 10000
set -g base-index 1
set-option -g default-terminal "screen-256color"
set -g status-bg colour235
set -g status-fg colour136
set -g status-left '#[fg=colour166][#S] '
set -g status-right '#[fg=colour166]%H:%M %d-%b #[fg=colour136]| redteam-lab'
bind | split-window -h
bind - split-window -v
bind r source-file ~/.tmux.conf \; display "Config recarregado!"
TMUX
    chown kali:kali /home/kali/.tmux.conf 2>/dev/null || true
}

# ─── 13. Script de sessão rápida ──────────────────────────────────────────────
create_lab_session_script() {
    cat > /usr/local/bin/lab-start << 'SESSION'
#!/usr/bin/env bash
GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
echo -e "${BOLD}${CYAN}"
echo "  ╔═══════════════════════════════════╗"
echo "  ║     🔴  RED TEAM LAB  🔴          ║"
echo "  ╚═══════════════════════════════════╝"
echo -e "${NC}"
echo -e "${GREEN}Serviços disponíveis:${NC}"
echo -e "  • DVWA:    http://127.0.0.1:8888  (admin/password)"
echo -e "  • OpenVAS: https://127.0.0.1:9392 (ver CREDENCIAIS-LAB.txt)"
echo -e "  • MobSF:   cd /opt/MobSF && ./run.sh 0.0.0.0:8000"
echo ""
echo -e "${GREEN}Alvos:${NC}"
echo -e "  • Metasploitable3: 192.168.56.20"
echo -e "  • DVWA Docker:     127.0.0.1:8888"
echo ""
echo -e "${GREEN}Comandos principais:${NC}"
echo -e "  vulhub list              → listar CVEs disponíveis"
echo -e "  vulhub start log4j/CVE-2021-44228"
echo -e "  android-lab devices      → ver emuladores"
echo -e "  android-lab frida-server → iniciar Frida"
echo -e "  lab-reset                → resetar para estado limpo"
echo -e "  msfconsole -q            → Metasploit"
echo ""
SESSION
    chmod +x /usr/local/bin/lab-start
}

# ─── 14. Resumo final ─────────────────────────────────────────────────────────
print_summary() {
    echo ""
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║          ✓  LABORATÓRIO INSTALADO COM SUCESSO!       ║${NC}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Acesso aos serviços:${NC}"
    echo -e "  DVWA:         ${GREEN}http://127.0.0.1:8888${NC}  → admin / password"
    echo -e "  OpenVAS:      ${GREEN}https://127.0.0.1:9392${NC} → ver ~/CREDENCIAIS-LAB.txt"
    echo -e "  MobSF:        ${GREEN}./run.sh 0.0.0.0:8000${NC}  → em /opt/MobSF"
    echo -e "  Metasploitable3: ${GREEN}192.168.56.20${NC}"
    echo ""
    echo -e "${CYAN}Comandos disponíveis:${NC}"
    echo -e "  ${YELLOW}lab-start${NC}     → resumo e status do lab"
    echo -e "  ${YELLOW}lab-reset${NC}     → resetar para estado limpo"
    echo -e "  ${YELLOW}vulhub${NC}        → gerenciar ambientes CVE"
    echo -e "  ${YELLOW}android-lab${NC}   → ferramentas Android"
    echo ""
    echo -e "${CYAN}Primeiros passos recomendados:${NC}"
    echo -e "  1. vulhub start log4j/CVE-2021-44228"
    echo -e "  2. nmap -sV 192.168.56.20"
    echo -e "  3. msfconsole -q"
    echo ""
    echo -e "  Log completo: ${BLUE}$LOG_FILE${NC}"
    echo ""
    echo -e "${RED}⚠️  Uso exclusivamente educacional e em ambiente isolado.${NC}"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    banner
    check_root

    log "Iniciando setup — Log: $LOG_FILE"
    mkdir -p "$LAB_DIR"

    local OS
    OS=$(check_os)
    info "Sistema detectado: $OS"

    case "$MODE" in
        --kali)
            provision_kali_tools
            setup_android_lab
            create_vulhub_helper
            create_reset_script
            create_lab_session_script
            ;;
        --android)
            setup_android_lab
            ;;
        --host)
            check_host_requirements
            install_host_dependencies
            setup_virtualbox_network
            setup_kali_vm
            setup_metasploitable3
            ;;
        --reset)
            log "Resetando laboratório..."
            [[ -f /usr/local/bin/lab-reset ]] && /usr/local/bin/lab-reset
            ;;
        *)
            # Instalação completa
            check_host_requirements

            if [[ "$OS" == "kali" ]]; then
                # Dentro do Kali: instalar ferramentas
                provision_kali_tools
                setup_android_lab
                create_vulhub_helper
                create_reset_script
                create_lab_session_script
            else
                # No host Ubuntu: instalar VirtualBox, Vagrant, VMs
                install_host_dependencies
                setup_virtualbox_network
                setup_kali_vm
                setup_metasploitable3
            fi
            ;;
    esac

    print_summary
}

main "$@"
