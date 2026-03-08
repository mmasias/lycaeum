#!/bin/bash
# lycaeum.sh — Transporte y coordinación de sesiones LYCAEUM
#
# Este script NO orquesta el debate. El moderador (un LLM) lo hace.
# Este script:
#   1. Lanza sesiones tmux con los CLIs
#   2. Carga los contextos compuestos (protocolo + dominio) en cada agente
#   3. Gestiona el transporte de tareas entre sesiones
#   4. Espera la aparición de archivos para avanzar entre fases
#
# Uso:
#   ./lycaeum.sh start       Lanza las sesiones tmux
#   ./lycaeum.sh ronda N     Gestiona la ronda N (Fase A + B)
#   ./lycaeum.sh status      Estado de todas las rondas
#   ./lycaeum.sh contexto    Recarga contextos en los agentes

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LYCAEUM_DIR="$SCRIPT_DIR/_LYCAEUM"
CONFIG_DIR="$SCRIPT_DIR/config"
CONF_FILE="$CONFIG_DIR/instancia/debate.conf"

# ── Cargar configuración ──
if [ ! -f "$CONF_FILE" ]; then
    echo "Error: no se encuentra $CONF_FILE"
    exit 1
fi
source "$CONF_FILE"

# ── Utilidades ──

wait_for_file() {
    local FILE=$1
    local LABEL=$2
    echo "⏳ Esperando $LABEL..."
    while [ ! -s "$FILE" ]; do
        inotifywait -q -e moved_to,close_write,create "$(dirname "$FILE")" 2>/dev/null
        sleep 0.5
    done
    echo "✓ $LABEL"
}

send_to() {
    local SESSION=$1
    local MSG=$2
    tmux send-keys -t "$SESSION" "$MSG"
    sleep 0.5
    tmux send-keys -t "$SESSION" "" Enter
    sleep 0.2
    tmux send-keys -t "$SESSION" "" Enter
}

# ── start: Lanza sesiones y carga contextos ──
cmd_start() {
    echo "Lanzando sesiones LYCAEUM..."

    # Matar sesiones previas
    tmux kill-session -t "$MODERADOR_SESION" 2>/dev/null || true
    for entrada in "${AGENTES[@]}"; do
        IFS=':' read -r nombre cli marco <<< "$entrada"
        tmux kill-session -t "lycaeum_${nombre}" 2>/dev/null || true
    done

    # Lanzar sesiones
    tmux new-session -d -s "$MODERADOR_SESION" -c "$SCRIPT_DIR"
    send_to "$MODERADOR_SESION" "$MODERADOR_CLI"
    sleep 2

    for entrada in "${AGENTES[@]}"; do
        IFS=':' read -r nombre cli marco <<< "$entrada"
        tmux new-session -d -s "lycaeum_${nombre}" -c "$SCRIPT_DIR"
        send_to "lycaeum_${nombre}" "$cli"
        sleep 2
    done

    # Cargar contextos
    echo "Cargando contextos..."
    cmd_contexto

    echo ""
    echo "Sesiones lanzadas. Para ver:"
    echo "  tmux attach -t $MODERADOR_SESION"
    for entrada in "${AGENTES[@]}"; do
        IFS=':' read -r nombre cli marco <<< "$entrada"
        echo "  tmux attach -t lycaeum_${nombre}"
    done
    echo ""
    echo "Siguiente paso: dile al moderador el objetivo y ejecuta:"
    echo "  ./lycaeum.sh ronda 1"
}

# ── contexto: Compone y carga protocolo+dominio en cada agente ──
cmd_contexto() {
    local PROTO_DIR="$CONFIG_DIR/protocolo"
    local DOM_DIR="$CONFIG_DIR/dominios/$DOMINIO"

    if [ ! -d "$DOM_DIR" ]; then
        echo "Error: dominio '$DOMINIO' no encontrado en $CONFIG_DIR/dominios/"
        exit 1
    fi

    # Componer contexto del moderador
    local MOD_CTX="$LYCAEUM_DIR/contexto_moderador.md"
    cat "$PROTO_DIR/moderador-base.md" > "$MOD_CTX"
    echo -e "\n---\n" >> "$MOD_CTX"
    cat "$DOM_DIR/moderador.md" >> "$MOD_CTX"
    send_to "$MODERADOR_SESION" "@${MOD_CTX}"
    sleep 2
    echo "  ✓ Moderador: protocolo + $DOMINIO"

    # Componer contexto de cada agente
    for entrada in "${AGENTES[@]}"; do
        IFS=':' read -r nombre cli marco <<< "$entrada"
        local AGT_CTX="$LYCAEUM_DIR/contexto_${nombre}.md"

        cat "$PROTO_DIR/agente-base.md" > "$AGT_CTX"
        echo -e "\n---\n" >> "$AGT_CTX"

        if [ -f "$DOM_DIR/${marco}.md" ]; then
            cat "$DOM_DIR/${marco}.md" >> "$AGT_CTX"
        else
            echo "Advertencia: marco '$marco' no encontrado en $DOM_DIR/"
        fi

        # Enviar contexto al agente
        # Workaround: algunos CLIs no aceptan @archivo
        if [[ "$cli" == "opencode" ]]; then
            send_to "lycaeum_${nombre}" "Lee el archivo ${AGT_CTX} y aplícalo como tu contexto"
        else
            send_to "lycaeum_${nombre}" "@${AGT_CTX}"
        fi
        sleep 2
        echo "  ✓ ${nombre}: protocolo + ${DOMINIO}/${marco}"
    done
}

# ── ronda N: Gestiona Fase A + Fase B ──
cmd_ronda() {
    local N=$(printf "%02d" "$1")
    local RONDA_DIR="$LYCAEUM_DIR/rondas/ronda_$N"
    mkdir -p "$RONDA_DIR"

    echo ""
    echo "════════════════════════════════════"
    echo "  LYCAEUM — Ronda $N"
    echo "════════════════════════════════════"

    # ── FASE A ──
    echo ""
    echo "── Fase A — Lecturas independientes ──"

    for entrada in "${AGENTES[@]}"; do
        IFS=':' read -r nombre cli marco <<< "$entrada"

        wait_for_file "$RONDA_DIR/task_${nombre}.md" "task_${nombre}.md"
        echo "  Enviando tarea a $nombre..."

        if [[ "$cli" == "opencode" ]]; then
            send_to "lycaeum_${nombre}" \
                "Lee _LYCAEUM/rondas/ronda_${N}/task_${nombre}.md y escribe tu respuesta en _LYCAEUM/rondas/ronda_${N}/response_${nombre}.md"
        else
            send_to "lycaeum_${nombre}" \
                "@_LYCAEUM/rondas/ronda_${N}/task_${nombre}.md"
        fi
        sleep "$INTERVALO"
    done

    echo "  Tareas Fase A enviadas."

    # Esperar las tres respuestas
    for entrada in "${AGENTES[@]}"; do
        IFS=':' read -r nombre cli marco <<< "$entrada"
        wait_for_file "$RONDA_DIR/response_${nombre}.md" "response_${nombre}.md"
    done

    echo ""
    echo "  ✓ Fase A completa."

    # Notificar al moderador
    send_to "$MODERADOR_SESION" \
        "Las lecturas de Fase A de la ronda $N están en _LYCAEUM/rondas/ronda_${N}/. Lee los response_*.md, identifica el punto de tensión y escribe los task_debate_*.md para la Fase B."
    sleep "$INTERVALO"

    # ── FASE B ──
    echo ""
    echo "── Fase B — Debate ──"

    for entrada in "${AGENTES[@]}"; do
        IFS=':' read -r nombre cli marco <<< "$entrada"

        wait_for_file "$RONDA_DIR/task_debate_${nombre}.md" "task_debate_${nombre}.md"
        echo "  Enviando debate a $nombre..."

        send_to "lycaeum_${nombre}" \
            "Lee _LYCAEUM/rondas/ronda_${N}/task_debate_${nombre}.md y responde en _LYCAEUM/rondas/ronda_${N}/debate_${nombre}.md"
        sleep "$INTERVALO"
    done

    echo "  Tareas Fase B enviadas."

    # Esperar las tres respuestas
    for entrada in "${AGENTES[@]}"; do
        IFS=':' read -r nombre cli marco <<< "$entrada"
        wait_for_file "$RONDA_DIR/debate_${nombre}.md" "debate_${nombre}.md"
    done

    echo ""
    echo "  ✓ Fase B completa."

    # Notificar al moderador
    send_to "$MODERADOR_SESION" \
        "Las respuestas del debate de la ronda $N están en _LYCAEUM/rondas/ronda_${N}/. Lee los debate_*.md, actualiza el blackboard.md y avísame cuando estés listo."

    echo ""
    echo "════════════════════════════════════"
    echo "  Ronda $N completa."
    echo "  Siguiente: ./lycaeum.sh ronda $((10#$N + 1))"
    echo "════════════════════════════════════"
}

# ── status: Estado de las rondas ──
cmd_status() {
    echo "LYCAEUM — Estado"
    echo "================"
    echo "Dominio: $DOMINIO"
    echo ""

    if [ ! -d "$LYCAEUM_DIR/rondas" ]; then
        echo "  Sin rondas iniciadas."
        return
    fi

    for dir in "$LYCAEUM_DIR"/rondas/ronda_*/; do
        [ -d "$dir" ] || continue
        local N=$(basename "$dir" | sed 's/ronda_//')
        local FA="pendiente" FB="pendiente"

        local all_responses=true
        local all_debates=true
        for entrada in "${AGENTES[@]}"; do
            IFS=':' read -r nombre cli marco <<< "$entrada"
            [ -f "$dir/response_${nombre}.md" ] || all_responses=false
            [ -f "$dir/debate_${nombre}.md" ] || all_debates=false
        done

        $all_responses && FA="✓"
        $all_debates && FB="✓"

        echo "  Ronda $N — Fase A: $FA  Fase B: $FB"
    done
}

# ── Dispatcher ──
case "${1:-}" in
    start)    cmd_start ;;
    ronda)    cmd_ronda "${2:?Falta número de ronda}" ;;
    status)   cmd_status ;;
    contexto) cmd_contexto ;;
    *)
        echo "LYCAEUM — Sistema multi-agente de análisis crítico"
        echo ""
        echo "Uso:"
        echo "  ./lycaeum.sh start       Lanza sesiones tmux y carga contextos"
        echo "  ./lycaeum.sh ronda N     Gestiona la ronda N (Fase A + B)"
        echo "  ./lycaeum.sh status      Estado de las rondas"
        echo "  ./lycaeum.sh contexto    Recarga contextos (protocolo + dominio)"
        echo ""
        echo "Configuración: config/instancia/debate.conf"
        echo "Dominio actual: $(source "$CONF_FILE" 2>/dev/null && echo "$DOMINIO" || echo "no configurado")"
        ;;
esac
