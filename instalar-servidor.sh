#!/usr/bin/env bash
# Instala/atualiza o servidor do Trilhas da Vida numa VPS Debian/Ubuntu.
#   curl -fsSL https://raw.githubusercontent.com/kevrauzika/TrilhasDaVida-download/HEAD/instalar-servidor.sh | sudo bash
# Roda o "salão" (serviço trilhas, UDP 7777): pelo jogo os jogadores criam, veem e excluem salas
# (Jogar com amigos > Salas no servidor). Cada sala é um processo filho do salão, numa porta UDP 7801-7808.
# Rodar de novo atualiza o servidor e reinicia o salão e as salas.
#   systemctl status trilhas · journalctl -u trilhas -f
# Salas e progresso: /var/lib/trilhas/.local/share/godot/app_userdata/Trilhas da Vida/ (salas.json, servidor_<porta>.json)
# Saves da versão antiga (servidor.json, servidor_<porta>.json) viram salas sem dono na primeira vez que o salão sobe.
set -euo pipefail

URL="${TRILHAS_SERVIDOR_URL:-https://github.com/kevrauzika/TrilhasDaVida-download/releases/latest/download/TrilhasDaVida-servidor-linux.zip}"
PASTA=/opt/trilhas
DADOS="/var/lib/trilhas/.local/share/godot/app_userdata/Trilhas da Vida"
PORTA=7777         # Salao.PORTA
SALAS=7801:7808    # Salao.PORTA + DESLOCAMENTO_SALAS, MAX_SALAS salas

[ "$(id -u)" -eq 0 ] || { echo "Rode como root (sudo)."; exit 1; }
[ "$(uname -m)" = "x86_64" ] || { echo "Esta VPS é $(uname -m); o servidor é só para x86_64."; exit 1; }

# Mesmo código de sala do jogo (Rede.codificar): IPv4 + porta em 10 caracteres base32 de Crockford.
codigo() {
	local A=0123456789ABCDEFGHJKMNPQRSTVWXYZ s="" i a b c d n
	IFS=. read -r a b c d <<<"$1"
	n=$(( ((a << 40) | (b << 32) | (c << 24) | (d << 16)) | $2 ))
	for i in 1 2 3 4 5 6 7 8 9 10; do s="${A:$((n & 31)):1}$s"; n=$((n >> 5)); done
	echo "${s:0:5}-${s:5}"
}

echo "[1/5] Baixando o servidor"
command -v unzip >/dev/null && command -v curl >/dev/null || { apt-get update -qq && apt-get install -y -qq unzip curl; }
TMP=$(mktemp -d)
trap 'rm -r "$TMP"' EXIT
curl -fsSL "$URL" -o "$TMP/servidor.zip"
unzip -q -o "$TMP/servidor.zip" -d "$TMP"

echo "[2/5] Parando as versões antigas (salas fixas trilhas@<porta> e sala única)"
for u in /etc/systemd/system/multi-user.target.wants/trilhas@*.service; do
	[ -L "$u" ] || [ -e "$u" ] || continue
	systemctl disable --now "$(basename "$u")" >/dev/null 2>&1 || true
done
systemctl stop 'trilhas@*' >/dev/null 2>&1 || true
systemctl disable --now trilhas >/dev/null 2>&1 || true
rm -f /etc/systemd/system/trilhas@.service /etc/systemd/system/multi-user.target.wants/trilhas@*.service
systemctl daemon-reload

echo "[3/5] Instalando em $PASTA"
id trilhas >/dev/null 2>&1 || useradd --system --home-dir /var/lib/trilhas --create-home --shell /usr/sbin/nologin trilhas
mkdir -p "$PASTA"
install -m 755 "$TMP/TrilhasDaVida.x86_64" "$PASTA/TrilhasDaVida.x86_64"

echo "[4/5] Criando o serviço trilhas (salão na porta $PORTA, liga sozinho com a VPS)"
cat > /etc/systemd/system/trilhas.service <<EOF
[Unit]
Description=Trilhas da Vida - salão de salas coop (UDP $PORTA, salas $SALAS)
After=network-online.target
Wants=network-online.target

[Service]
User=trilhas
WorkingDirectory=/var/lib/trilhas
ExecStart=$PASTA/TrilhasDaVida.x86_64 --headless -- --salao
Restart=always
RestartSec=3
# salão + até 8 salas de ~90 MB cada; o KillMode padrão (control-group) encerra as salas junto com o salão
MemoryMax=1G

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable trilhas >/dev/null 2>&1
systemctl restart trilhas

echo "[5/5] Liberando UDP $PORTA e $SALAS"
if command -v ufw >/dev/null && ufw status | grep -q active; then
	ufw allow "$PORTA"/udp >/dev/null
	ufw allow "$SALAS"/udp >/dev/null
	echo "  ufw: portas liberadas"
else
	echo "  (sem ufw ativo; nada a fazer aqui)"
fi

sleep 4
if ! systemctl is-active --quiet trilhas; then
	echo "O salão não subiu. Veja: journalctl -u trilhas -n 30"
	exit 1
fi
IP=$(curl -fsS4 https://api.ipify.org || true)
echo
echo "Pronto! O salão está no ar."
PORTAS=$(grep -oE '"porta": *[0-9]+' "$DADOS/salas.json" 2>/dev/null | grep -oE '[0-9]+' | sort -un || true)
if [ -n "$PORTAS" ]; then
	echo "Salas existentes:"
	for s in $PORTAS; do
		if [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "  porta $s  ->  código $(codigo "$IP" "$s")"; else echo "  porta $s"; fi
	done
fi
echo
echo "No jogo: Jogar com amigos > Salas no servidor"
echo "Dentro da sala, Esc > Copiar convite gera a mensagem pronta para mandar aos amigos."
echo "Se o provedor da VPS tiver firewall no painel, libere lá também UDP $PORTA e 7801-7808."
