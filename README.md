# Trilhas da Vida — instalar

RPG 2D aconchegante de exploração ecológica na Mata Atlântica, para jogar sozinho ou com até 3 amigos.
Este repositório tem só o instalador e o jogo pronto (Windows). O código-fonte é privado.

![Quatro jogadores na vila](telas/coop.png)

## Instalar

Abra o **PowerShell** e cole:

```powershell
irm https://raw.githubusercontent.com/kevrauzika/TrilhasDaVida-download/HEAD/install.ps1 | iex
```

O jogo é instalado em `%LOCALAPPDATA%\TrilhasDaVida` e o atalho **Trilhas da Vida** aparece na Área de Trabalho.
Rodar o comando de novo atualiza o jogo; o progresso salvo é mantido.

Desinstalar:

```powershell
irm https://raw.githubusercontent.com/kevrauzika/TrilhasDaVida-download/HEAD/desinstalar.ps1 | iex
```

## Jogar com amigos (até 4)

1. Entre numa sala: menu → **Jogar com amigos** → digite o código → **Entrar na sala**. (Sem servidor, alguém clica em **Hospedar sala**; na primeira vez, o Windows pergunta sobre o firewall: clique em **Permitir acesso**.)
2. Na pausa (**Esc**) aparece o código da sala e o botão **Copiar convite**: ele copia uma mensagem pronta com o comando de instalar, o código e como entrar. É só colar no chat.

![Copiar convite na pausa](telas/convite.png)

Pela internet, o jeito mais fácil é todos usarem o [Tailscale](https://tailscale.com/download) na mesma rede e usar o código "Tailscale". No mesmo Wi-Fi, use o código "Mesma rede".

### Servidor dedicado (VPS)

Numa VPS Debian/Ubuntu (x86_64), rode:

```bash
curl -fsSL https://raw.githubusercontent.com/kevrauzika/TrilhasDaVida-download/HEAD/instalar-servidor.sh | sudo bash
```

A sala fica sempre aberta na porta **UDP 7777** (libere-a também no firewall do painel do provedor), o progresso do grupo fica salvo na VPS e o script mostra o **código da sala**. Cada sala usa ~90 MB de RAM.

Outra sala para outro grupo (progresso separado), na porta 7778:

```bash
curl -fsSL https://raw.githubusercontent.com/kevrauzika/TrilhasDaVida-download/HEAD/instalar-servidor.sh | sudo bash -s -- 7778
```

Rodar o comando de novo atualiza o servidor e reinicia todas as salas. Apagar uma sala: `systemctl disable --now trilhas@7778`.

## Controles

WASD ou setas para andar · Shift devagar · E interagir · C caderno · M mapa · F lanterna · Esc pausa

![Juliana na vila](telas/juliana.png)
