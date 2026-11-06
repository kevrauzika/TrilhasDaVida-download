#!/usr/bin/env bash
# Instala/atualiza o servidor dedicado do Trilhas da Vida numa VPS Debian/Ubuntu e cria uma sala.
#   curl -fsSL https://raw.githubusercontent.com/kevrauzika/TrilhasDaVida-download/HEAD/instalar-servidor.sh | sudo bash
# Outra sala (outro grupo, progresso separado): passe a porta.
#   curl -fsSL .../instalar-servidor.sh | sudo bash -s -- 7778
# Cada sala é o serviço trilhas@<porta>. Rodar de novo atualiza o servidor e reinicia todas as salas.
#   systemctl status trilhas@7777 · journalctl -u trilhas@7777 -f · systemctl disable --now trilhas@7778 (apaga a sala)
# Progresso: /var/lib/trilhas/.local/share/godot/app_userdata/Trilhas da Vida/servidor[_<porta>].json
set -euo pipefail

URL="${TRILHAS_SERVIDOR_URL:-https://github.com/kevrauzika/TrilhasDaVida-download/releases/latest/download/TrilhasDaVida-servidor-linux.zip}"
PASTA=/opt/trilhas
PORTA="${1:-7777}"

[ "$(id -u)" -eq 0 ] || { echo "Rode como root (sudo)."; exit 1; }
[ "$(uname -m)" = "x86_64" ] || { echo "Esta VPS é $(uname -m); o servidor é só para x86_64."; exit 1; }
[[ "$PORTA" =~ ^[0-9]+$ ]] && [ "$PORTA" -ge 1024 ] && [ "$PORTA" -le 65535 ] || { echo "Porta inválida: $PORTA (use 1024-65535)"; exit 1; }

# Mesmo código de sala do jogo (Rede.codificar): IPv4 + porta em 10 caracteres base32 de Crockford.
codigo() {
	local A=0123456789ABCDEFGHJKMNPQRSTVWXYZ s="" i a b c d n
	IFS=. read -r a b c d <<<"$1"
	n=$(( ((a << 40) | (b << 32) | (c << 24) | (d << 16)) | $2 ))
	for i in 1 2 3 4 5 6 7 8 9 10; do s="${A:$((n & 31)):1}$s"; n=$((n >> 5)); done
	echo "${s:0:5}-${s:5}"
}

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

echo "[3/4] Criando a sala da porta $PORTA (liga sozinha com a VPS)"
cat > /etc/systemd/system/trilhas@.service <<EOF
[Unit]
Description=Trilhas da Vida - sala coop na porta %i
After=network-online.target
Wants=network-online.target

[Service]
User=trilhas
WorkingDirectory=/var/lib/trilhas
ExecStart=$PASTA/TrilhasDaVida.x86_64 --headless -- --servidor --porta=%i
Restart=always
RestartSec=3
MemoryMax=300M

[Install]
WantedBy=multi-user.target
EOF
# versão antiga (uma sala só): vira trilhas@7777, com o mesmo progresso salvo
if [ -f /etc/systemd/system/trilhas.service ]; then
	systemctl disable --now trilhas >/dev/null 2>&1 || true
	rm -f /etc/systemd/system/trilhas.service
	systemctl daemon-reload
	systemctl enable --now trilhas@7777 >/dev/null 2>&1
fi
systemctl daemon-reload
systemctl enable trilhas@"$PORTA" >/dev/null 2>&1
SALAS=$(systemctl list-units --type=service --all --no-legend --plain 'trilhas@*' | awk '{print $1}' | grep -oE '^trilhas@[0-9]+' | sort -u)
for s in $SALAS trilhas@"$PORTA"; do systemctl restart "$s"; done

echo "[4/4] Liberando a porta UDP $PORTA"
if command -v ufw >/dev/null && ufw status | grep -q active; then
	ufw allow "$PORTA"/udp >/dev/null
	echo "  ufw: porta liberada"
else
	echo "  (sem ufw ativo; nada a fazer aqui)"
fi

sleep 2
if ! systemctl is-active --quiet trilhas@"$PORTA"; then
	echo "A sala não subiu. Veja: journalctl -u trilhas@$PORTA -n 30"
	exit 1
fi
IP=$(curl -fsS4 https://api.ipify.org || true)
echo
echo "Pronto! Salas nesta VPS:"
for s in $(systemctl list-units --type=service --state=active --no-legend --plain 'trilhas@*' | awk '{print $1}' | grep -oE '[0-9]+' | sort -un); do
	if [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "  porta $s  ->  código $(codigo "$IP" "$s")"; else echo "  porta $s"; fi
done
echo
echo "No jogo: Jogar com amigos > digite o código > Entrar na sala."
echo "Dentro da sala, Esc > Copiar convite gera a mensagem pronta para mandar aos amigos."
echo "Se o provedor da VPS tiver firewall no painel, libere a porta UDP $PORTA lá também."
