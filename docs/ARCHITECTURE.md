# Arquitectura técnica — Prototipo 0.1.0

```text
                  ┌─────────────────────────────────────────┐
Jugador ──────────► Main / UI: clic, teclado, chat, micrófono │
                  └──────────────┬──────────────────────────┘
                                 │
            ┌────────────────────┼───────────────────────────┐
            ▼                    ▼                           ▼
     [Simulation State]    [Pomi Agent / A*]          [House / objetos]
      reloj + necesidades   movimiento 3D            3 estancias + colisiones
      + recursos + reglas
            ▲
            │ datos verificados, no órdenes generativas
            │
     [Ollama bridge] ◄── texto usuario
     (127.0.0.1:11434)
            ▲
        texto transcrito
            ▲
      [Vosk bridge] ◄── WAV grabado en Godot
      (127.0.0.1:8765)
```

## Propiedad y restricciones

`SimState.execute_action` es el único punto que cambia necesidades y reduce inventarios por acción. `OllamaBridge` no recibe referencia al objeto `SimState` ni sus métodos mutables: solo un diccionario reducido de hechos. Las conversaciones no pueden inventar recursos ni acciones ejecutadas.

`PomiAgent` produce navegación y señal `arrived`. `Main` valida la interacción y espera antes de llamar `SimState.execute_action`. Las paredes visuales son independientes de reglas de paso (celdas bloqueadas de A*). En un futuro se unificará la ocupación de celdas con colliders y decoraciones, y se implementará navegación alrededor de muebles.

`House` crea mallas de cubos con `BaseMaterial3D.SHADING_MODE_UNSHADED`. El avatar importa `Pomi_Base_V05_Canonico.glb` con el mismo shading y filtro nearest. Actualmente el atlas original puede incluir tonos pintados que serán sustituidos en V06.

### Persistencia

JSON `save_version=1`; archivo `user://teseracta_save_v1.json` almacena reloj, necesidades, inventario, recuerdos de eventos, contador, posición y turnos de chat. En siguiente hito añadir guardado atómico, checksums, migraciones y copias de seguridad.

### Voz

Godot registra PCM con `AudioStreamMicrophone` y `AudioEffectRecord`, escribe temporalmente WAV, envía bytes vía `HTTPRequest.request_raw` al servidor Python de Vosk con escucha solo `127.0.0.1`. El servidor convierte WAV a PCM 16kHz mono antes de inferir. El audio no sale del equipo. Requiere habilitar el micrófono de Windows y levantar Python manualmente.

### Rendimiento

Un solo agente, A* de 25x17 celdas, simulación aritmética O(1) por frame, inferencia generativa solo al enviar mensajes. No hay inferencia permanente, backend remoto, ni streaming continuo de micrófono; el reconocimiento se pide por pulsación.
