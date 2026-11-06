#!/usr/bin/env bash
# Instala (ou atualiza) o servidor dedicado do Trilhas da Vida numa VPS Debian/Ubuntu.
#   curl -fsSL https://raw.githubusercontent.com/kevrauzika/TrilhasDaVida-download/HEAD/instalar-servidor.sh | sudo bash
# Sala permanente na porta UDP 7777, reinicia sozinho e guarda o progresso do grupo em
#   /var/lib/trilhas/.local/share/godot/app_userdata/Trilhas da Vida/servidor.json
# Comandos úteis: systemctl status trilhas · journalctl -u trilhas -f · systemctl restart trilhas
set -euo pipefail

URL="${TRILHAS_SERVIDOR_URL:-https://github.com/kevrauzika/TrilhasDaVida-download/releases/latest/download/TrilhasDaVida-servidor-linux.zip}"
PASTA=/opt/trilhas
PORTA=7777

[ "$(id -u)" -eq 0 ] || { echo "Rode como root (sudo)."; exit 1; }
[ "$(uname -m)" = "x86_64" ] || { echo "Esta VPS é $(uname -m); o servidor é só para x86_64."; exit 1; }

echo "[1/4] Baixando o servidor"
command -v unzip >/dev/null && command -v curl >/dev/null || { apt-get update -qq && apt-get install -y -qq unzip curl; }
TMP=$(mktemp -d)
trap 'rm -r "$TMP"' EXIT
curl -fsSL "$URL" -o "$TMP/servidor.zip"
unzip -q -o "$TMP/servidor.zip" -d "$TMP"

echo "[2/4] Instalando em $PASTA"
id trilhas >/dev/null 2>&1 || useradd --system --home-dir /var/lib/trilhas --create-home --shell /usr/sbin/nologin trilhas
mkdir -p "$PASTA"
install -m 755 "$TMP/TrilhasDaVida.x86_64" "$PASTA/TrilhasDaVida.x86_64"

echo "[3/4] Criando o serviço (liga sozinho com a VPS)"
cat > /etc/systemd/system/trilhas.service <<EOF
[Unit]
Description=Trilhas da Vida - servidor coop
After=network-online.target
Wants=network-online.target

[Service]
User=trilhas
WorkingDirectory=/var/lib/trilhas
ExecStart=$PASTA/TrilhasDaVida.x86_64 --headless -- --servidor
Restart=always
RestartSec=3
MemoryMax=300M

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now trilhas >/dev/null 2>&1
systemctl restart trilhas

echo "[4/4] Liberando a porta UDP $PORTA"
if command -v ufw >/dev/null && ufw status | grep -q active; then
	ufw allow $PORTA/udp >/dev/null
	echo "  ufw: porta liberada"
else
	echo "  (sem ufw ativo; nada a fazer aqui)"
fi

sleep 2
if systemctl is-active --quiet trilhas; then
	IP=$(curl -fsS4 https://api.ipify.org || echo "IP-da-VPS")
	echo
	echo "Pronto! Servidor rodando. No jogo: Jogar com amigos > digite $IP > Entrar na sala."
	echo "Se o provedor da VPS tiver firewall no painel, libere a porta UDP $PORTA lá também."
else
	echo "O serviço não subiu. Veja: journalctl -u trilhas -n 30"
	exit 1
fi
