#!/bin/bash

###############################################################################
# AI Deployer - VPS Kurulum Betiği (Ubuntu Server 26)
# IP ve Port Tabanlı Doğrudan Erişim Yapılandırması
###############################################################################

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_logo() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════╗
║                      AI Deployer - VPS Kurulum                            ║
║                                                                           ║
║                 Ollama + Open WebUI + n8n + Redis                         ║
║                                                                           ║
║             Sadece IP ve Port Üzerinden Doğrudan Erişim                   ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

info() { echo -e "${BLUE}[ℹ️ BİLGİ]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
error() { echo -e "${RED}[✗ HATA]${NC} $1"; exit 1; }
warning() { echo -e "${YELLOW}[⚠️]${NC} $1"; }

check_system() {
    info "Sistem kontrolleri yapılıyor..."
    if [[ $EUID -eq 0 ]]; then
        error "Bu betiği doğrudan root kullanıcısı ile çalıştırmayın. Sudo yetkisine sahip normal bir kullanıcı kullanın."
    fi
    if ! command -v sudo &> /dev/null; then
        error "sudo paketi sistemde bulunamadı."
    fi
    success "Sistem kontrolleri tamamlandı."
}

update_system() {
    info "Sistem paket listesi güncelleniyor..."
    sudo apt-get update
    sudo apt-get upgrade -y
    success "Sistem paketleri güncellendi."
}

install_dependencies() {
    info "Gerekli bağımlılıklar kuruluyor..."
    sudo apt-get install -y \
        curl wget git htop net-tools vim nano \
        build-essential libssl-dev libffi-dev python3-pip
    success "Bağımlılıklar kuruldu."
}

install_docker() {
    info "Docker Engine kontrol ediliyor..."
    if command -v docker &> /dev/null; then
        success "Docker zaten sistemde kurulu."
        return
    fi

    info "Docker kurulumu başlatılıyor..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    sudo systemctl start docker
    sudo systemctl enable docker
    
    if ! groups $USER | grep -q docker; then
        sudo usermod -aG docker $USER
        warning "Kullanıcınız docker grubuna eklendi. Değişikliklerin uygulanması için oturumu kapatıp açmanız gerekebilir."
    fi
    success "Docker başarıyla kuruldu."
}

clone_repository() {
    info "Repository dizini kontrol ediliyor..."
    if [[ ! -d "aideployer" ]]; then
        git clone https://github.com/xquattro/aideployer.git aideployer
        cd aideployer
        success "Repository klonlandı."
    else
        warning "aideployer dizini zaten mevcut, güncel kodlar çekiliyor..."
        cd aideployer
        git pull
    fi
}

setup_env() {
    info "Ortam dosyası (.env) kontrol ediliyor..."
    if [[ ! -f ".env" ]]; then
        if [[ -f ".env.example" ]]; then
            cp .env.example .env
            info ".env.example dosyasından .env oluşturuldu."
        else
            error ".env.example dosyası bulunamadı. Lütfen repoda mevcut olduğundan emin olun."
        fi
    fi
    success ".env dosyası hazır."
}

start_containers() {
    info "Docker konteynerleri ayağa kaldırılıyor..."
    docker compose up -d
    success "Konteynerler arka planda başlatıldı."
    
    info "Servislerin sağlık kontrolleri (Healthcheck) bekleniyor (30 sn)..."
    sleep 30
}

download_ollama_model() {
    info "Ollama üzerinde temel LLM modeli yükleniyor..."
    info "Mistral modeli indiriliyor..."
    docker exec -it ollama ollama pull mistral
    success "Model başarıyla içeri aktarıldı."
}

show_container_status() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN} Servis Durumları (Docker Compose PS):${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"
    docker compose ps
}

show_system_info() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN} Sistem Kaynak Durumu:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"
    echo -e "${BLUE}İşlemci Çekirdek Sayısı:${NC} $(nproc)"
    echo -e "${BLUE}Bellek Durumu:${NC}"
    free -h | head -2
    echo -e "\n${BLUE}Disk Durumu:${NC}"
    df -h / | tail -1
}

show_access_info() {
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    PUBLIC_IP=$(curl -s --max-time 5 https://ifconfig.me || echo "$LOCAL_IP")

    echo -e "\n${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ KURULUM BAŞARIYLA TAMAMLANDI!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${YELLOW}📍 Erişim Detayları:${NC}\n"
    echo -e "${BLUE}Open WebUI (Arayüz):${NC}"
    echo "  🌐 URL: http://${PUBLIC_IP}:8080"
    echo "  💡 Not: İlk girişte oluşturacağınız hesap yönetici hesabı olacaktır."
    echo ""
    echo -e "${BLUE}n8n (Otomasyon):${NC}"
    echo "  🌐 URL: http://${PUBLIC_IP}:5678"
    echo ""
    echo -e "${BLUE}Ollama API Endpoint:${NC}"
    echo "  🔌 Adres: http://${PUBLIC_IP}:11434"
    echo "  📦 Varsayılan Model: mistral"
    echo ""
    echo -e "${BLUE}PostgreSQL:${NC}"
    echo "  🗄️  Port: 5432 (Konteyner içi ağda çalışır)"
    echo ""
    echo -e "${BLUE}Redis Cache:${NC}"
    echo "  💾 Port: 6379"
    echo ""
    
    echo -e "${YELLOW}📋 Temel Yönetim Komutları:${NC}\n"
    echo "  # Konteyner durumlarını inceleme:"
    echo "  docker compose ps"
    echo ""
    echo "  # Canlı log takibi:"
    echo "  docker compose logs -f [servis_adi]"
    echo ""
    echo "  # Altyapıyı durdurma:"
    echo "  docker compose down"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}\n"
}

main() {
    print_logo
    read -p "$(echo -e "${YELLOW}Kuruluma başlamak istiyor musunuz? (e/h): ${NC}")" choice
    if [[ "$choice" != "e" && "$choice" != "E" ]]; then
        info "Kurulum kullanıcı tarafından iptal edildi."
        exit 0
    fi
    
    check_system
    update_system
    install_dependencies
    install_docker
    clone_repository
    setup_env
    start_containers
    download_ollama_model
    show_container_status
    show_system_info
    show_access_info
}

main "$@"
