#!/bin/bash

###############################################################################
# AI Deployer - VPS Kurulum Betiği (Ubuntu Server 26)
# Ollama + Open WebUI + n8n + Nginx SSL
###############################################################################

set -e

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================
# Fonksiyonlar
# ============================================

print_logo() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════════════╗
║                      AI Deployer - VPS Kurulum                           ║
║                                                                           ║
║            Ollama + Open WebUI + n8n + Nginx SSL (Let's Encrypt)        ║
║                                                                           ║
║                    Ubuntu Server 26 için Optimize                        ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

info() {
    echo -e "${BLUE}[ℹ️  BİLGİ]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

error() {
    echo -e "${RED}[✗ HATA]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[⚠️ ]${NC} $1"
}

# ============================================
# Sistem Kontrolleri
# ============================================

check_system() {
    info "Sistem kontrolleri yapılıyor..."
    
    if [[ $EUID -eq 0 ]]; then
        error "Bu betiği root olarak çalıştırmayın"
    fi
    
    if ! command -v sudo &> /dev/null; then
        error "sudo gereklidir"
    fi
    
    success "Sistem kontrolleri tamamlandı"
}

# ============================================
# Paket Yöneticisini Güncelle
# ============================================

update_system() {
    info "Sistem paketleri güncelleniyor..."
    sudo apt-get update
    sudo apt-get upgrade -y
    success "Sistem güncellendi"
}

# ============================================
# Gerekli Paketleri Kur
# ============================================

install_dependencies() {
    info "Gerekli paketler kuruluyordu..."
    
    sudo apt-get install -y \
        curl \
        wget \
        git \
        htop \
        net-tools \
        vim \
        nano \
        build-essential \
        libssl-dev \
        libffi-dev \
        python3-pip
    
    success "Paketler kuruldu"
}

# ============================================
# Docker ve Docker Compose Kurulumu
# ============================================

install_docker() {
    info "Docker kuruluyordu..."
    
    if command -v docker &> /dev/null; then
        success "Docker zaten kurulu"
        return
    fi
    
    # Docker kurulum anahtarı ve deposu
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
    
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Docker'ı başlat ve etkinleştir
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Mevcut kullanıcıyı docker grubuna ekle
    if ! groups $USER | grep -q docker; then
        sudo usermod -aG docker $USER
        warning "Docker grubuna eklendi. Lütfen yeni bir terminal açınız"
    fi
    
    success "Docker kuruldu"
}

# ============================================
# Docker Compose Kontrol
# ============================================

install_docker_compose() {
    info "Docker Compose kontrol ediliyor..."
    
    if command -v docker-compose &> /dev/null; then
        success "Docker Compose zaten kurulu"
        return
    fi
    
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    success "Docker Compose kuruldu"
}

# ============================================
# Git Deposunu Klonla
# ============================================

clone_repository() {
    info "Repository klonlanıyor..."
    
    if [[ ! -d "aideployer" ]]; then
        git clone https://github.com/xquattro/aideployer.git aideployer
        success "Repository klonlandı"
    else
        warning "Dizin zaten var, güncelleme yapılıyor..."
        cd aideployer
        git pull
        cd ..
    fi
}

# ============================================
# Çevre Dosyasını Hazırla
# ============================================

setup_env() {
    info "Ortam dosyası hazırlanıyor..."
    
    cd aideployer
    
    if [[ ! -f ".env" ]]; then
        cp .env.example .env 2>/dev/null || echo "# Ortam dosyası oluşturuluyor..."
    fi
    
    success ".env dosyası hazır"
    cd ..
}

# ============================================
# Nginx Klasörü ve SSL Dizini Oluştur
# ============================================

setup_nginx() {
    info "Nginx yapılandırması hazırlanıyor..."
    
    cd aideployer
    
    mkdir -p nginx/ssl
    
    success "Nginx dizini oluşturuldu"
    cd ..
}

# ============================================
# Docker Containers'ı Başlat
# ============================================

start_containers() {
    info "Docker containers başlatılıyor..."
    
    cd aideployer
    
    docker-compose up -d
    
    success "Containers başlatıldı"
    
    # Containers'ın başlaması için bekle
    info "Containers'ın hazır olması için bekleniyor (30 saniye)..."
    sleep 30
    
    cd ..
}

# ============================================
# Ollama Model Yükle
# ============================================

download_ollama_model() {
    info "Ollama modeli yükleniyor..."
    
    info "Misrtal modelini indiriyoruz (En populer ve hafif)..."
    docker exec ollama ollama pull mistral
    
    success "Ollama modeli yüklendi"
}

# ============================================
# Docker Compose Durumunu Göster
# ============================================

show_container_status() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Docker Containers Durumu:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    
    cd aideployer
    docker-compose ps
    cd ..
}

# ============================================
# Sistem Bilgileri Göster
# ============================================

show_system_info() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Sistem Bilgileri:${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${BLUE}IP Adresi:${NC}"
    hostname -I
    
    echo ""
    echo -e "${BLUE}CPU Bilgisi:${NC}"
    nproc
    
    echo ""
    echo -e "${BLUE}Bellek:${NC}"
    free -h | head -2
    
    echo ""
    echo -e "${BLUE}Disk:${NC}"
    df -h / | tail -1
}

# ============================================
# Erişim Bilgileri
# ============================================

show_access_info() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ KURULUM TAMAMLANDI!${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}📍 Erişim Adresleri:${NC}"
    echo ""
    echo -e "${BLUE}Open WebUI:${NC}"
    echo "  🌐 URL: http://204.168.255.122:8080"
    echo "  👤 Kullanıcı: burak"
    echo "  🔑 Şifre: Pass.123"
    echo ""
    
    echo -e "${BLUE}n8n (Workflow):${NC}"
    echo "  🌐 URL: http://204.168.255.122:5678"
    echo "  👤 Kullanıcı: burak"
    echo "  🔑 Şifre: Pass.123"
    echo ""
    
    echo -e "${BLUE}Ollama API:${NC}"
    echo "  🔌 Adres: http://204.168.255.122:11434"
    echo "  📦 Model: mistral"
    echo ""
    
    echo -e "${BLUE}PostgreSQL:${NC}"
    echo "  🗄️  Adres: localhost:5432"
    echo "  👤 Kullanıcı: n8n_user"
    echo ""
    
    echo -e "${BLUE}Redis Cache:${NC}"
    echo "  💾 Adres: localhost:6379"
    echo ""
    
    echo -e "${YELLOW}📋 Faydalı Komutlar:${NC}"
    echo ""
    echo "  # Containers durumunu görmek:"
    echo "  cd aideployer && docker-compose ps"
    echo ""
    echo "  # Logs görmek:"
    echo "  docker-compose logs -f open-webui"
    echo "  docker-compose logs -f n8n"
    echo ""
    echo "  # Containers'ı durdur:"
    echo "  docker-compose down"
    echo ""
    echo "  # Containers'ı yeniden başlat:"
    echo "  docker-compose restart"
    echo ""
    
    echo -e "${YELLOW}📖 Sonraki Adımlar:${NC}"
    echo ""
    echo "  1. Open WebUI'ye girin: http://204.168.255.122:8080"
    echo "  2. n8n'de workflow oluşturun: http://204.168.255.122:5678"
    echo "  3. SSL sertifikası ekleyin (eğer domain varsa)"
    echo ""
}

# ============================================
# Ana Kurulum Fonksiyonu
# ============================================

main() {
    print_logo
    
    read -p "$(echo -e "${YELLOW}Kuruluma başlamak istiyor musunuz? (e/h): ${NC}")" choice
    if [[ "$choice" != "e" ]]; then
        info "Kurulum iptal edildi"
        exit 0
    fi
    
    check_system
    update_system
    install_dependencies
    install_docker
    install_docker_compose
    clone_repository
    setup_env
    setup_nginx
    start_containers
    download_ollama_model
    
    show_container_status
    show_system_info
    show_access_info
}

# Kurulumu çalıştır
main "$@"
