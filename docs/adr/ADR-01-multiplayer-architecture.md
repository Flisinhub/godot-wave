# ADR-01: Arquitectura de Red y Multijugador Cooperativo

## Estado
Aceptado

## Contexto
SFE5 es un juego cooperativo de 1 a 10 jugadores con hasta miles de unidades del enjambre en pantalla, combate en tiempo real, progresión RPG y eventos sincronizados.
Se evaluaron dos modelos de arquitectura de red en Godot 4.7:
1. **Lockstep determinista (estilo RTS clásico StarCraft):**
   - Todos los clientes simulan cada fotograma sincronizados por turnos de comandos.
   - *Inconvenientes:* En Godot 4 con física 3D y punto flotante nativo, garantizar determinismo idéntico bit a bit entre diferentes arquitecturas de CPU (x86 vs ARM) y compilaciones es extremadamente frágil. Una sola desincronización corrompe la partida irreversiblemente y hace la reconexión en caliente prácticamente imposible.
2. **Host autoritativo con ENet y Snapshots Comprimidos de Enjambre:**
   - El Host simula la simulación física completa, engendradores y compras.
   - Los clientes envían órdenes de entrada de su héroe (`move_to`, `cast_skill`, `buy_upgrade`) validadas por el servidor.
   - El enjambre masivo se transmite mediante deltas y snapshots empaquetados (`PackedByteArray`) interpolados visualmente en cliente.
   - Permite reconexión en caliente y desconexión segura sin congelar a los demás jugadores.

## Decisión
Adoptamos el modelo de **Host Autoritativo con ENetMultiplayerPeer y Snapshots Comprimidos**.

## Consecuencias
- Partidas estables sin desincronizaciones de punto flotante.
- Soporte nativo para reconexión de jugadores caídos con recálculo dinámico de suministro.
- Los clientes disfrutan de respuesta predictiva local para el movimiento de su héroe mientras el servidor mantiene la autoridad de combate.
