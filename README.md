# TESERACTA — Prototipo Pomi + Casa 0.1.0

**Godot 4.x · Windows 11 · 3D low-poly isométrico · sin pixel art en la geometría · materiales sin sombreado.**

El objetivo de este prototipo vertical es validar **una sola vida simulada** en **una sola vivienda**, antes de desarrollar la ciudad-estado de Teseracta. El protagonista utiliza el modelo canónico `Pomi_V05_LIGERO_MOVIL.bbmodel` como referencia editable y un `.glb` derivado de su geometría original para Godot.

## 1. Qué contiene ya

- Vivienda 3D, estilo diorama, con **dormitorio**, **cocina-salón** y **cuarto de baño**; muebles seleccionables; paredes frontales ocultas para cámara isométrica.
- Pomi que puede desplazarse entre habitaciones mediante AStarGrid2D; acciones de **comer, dormir, ir al baño, ducharse y descansar**.
- Simulación independiente de **saciedad, energía, vejiga, higiene, diversión y estado de ánimo**; reloj, comida, agua y créditos.
- Elegir acciones con clic sobre los muebles o botones; modo autónomo cuando el jugador no interviene.
- **Guardar/cargar** en JSON versionado.
- Diálogo opcional con **Ollama + Qwen3 1.7B** por HTTP local; los mensajes del LLM **no ejecutan acciones** ni crean bienes.
- Grabación de voz desde Godot y transcripción en español mediante servidor local **Vosk** (`voice/server.py`), opcional.
- Materiales de la casa **unshaded** y colores planos; el Pomi conserva temporalmente el atlas V05 original, que se revisará después.

El modelo actualmente conserva su ropa interior y manos originales. La retirada de ropa interior, dedos separados y repintado sin sombras quedan **pendientes** de una revisión independiente de arte V06: no se ha sustituido ni deformado el canon.

## 2. Iniciar la primera demo (sin inteligencia artificial)

1. Descarga este proyecto completo como ZIP, descomprímelo en tu ordenador Windows 11 y mantén intacta la estructura de carpetas.
2. Instala Godot desde **https://godotengine.org/download/windows/** y abre Godot → **Importar** → selecciona `project.godot`.
3. Espera a que importe `assets/characters/Pomi_Base_V05_Canonico.glb` y abre el proyecto con **F6/F5** (F5 ejecuta la escena principal).
4. Mueve el ratón sobre el diorama, haz clic en los muebles o pulsa botones. La rueda ajusta el zoom. Guarda y carga cuando quieras.
5. Si aparece el avatar provisional, falta el `.glb`. El ZIP completo sí incluye el asset. La rama de código de GitHub puede omitir recursos binarios temporalmente.

### No hace falta instalar Ollama ni Vosk para empezar
La simulación de necesidades funciona con reglas deterministas. Si hablas por texto sin Ollama, aparecerá un aviso en lugar de congelarse el juego.

## 3. Instalar la IA que conversa (Ollama / Qwen3)

**Recomendación para 16 GB RAM y GPU modesta:** Qwen3 1.7B; descarga de unos **1,4 GB**. Si resulta lento, prueba `qwen3:0.6b`, unos **523 MB**. No hay API de pago. El modelo se descarga al disco de Windows, **no dentro del repositorio**.

1. Abre https://ollama.com/download/windows/ y descarga e instala Ollama.
2. Abre **PowerShell** en Windows y ejecuta:

   ```powershell
   ollama pull qwen3:1.7b
   ollama list
   ```

3. Normalmente Ollama mantiene su servidor local en `http://127.0.0.1:11434`. Si no está en marcha, abre Ollama o ejecuta `ollama serve` en una terminal cuando corresponda.
4. En Godot pulsa **F5**, escribe una frase y pulsa **Enviar**. Godot llama a `POST http://127.0.0.1:11434/api/chat` con `stream=false` y el contexto del Pomi.
5. Si el rendimiento es insuficiente, ejecuta `ollama pull qwen3:0.6b` y cambia `model_name` en `scripts/ollama_bridge.gd` a `qwen3:0.6b`.

**Dónde está el modelo:** Ollama gestiona sus ficheros localmente, en una carpeta propia de usuario. No copies el modelo a Godot, no lo subas a GitHub y no abras puertos públicos. El servicio de Godot y Ollama se comunica por localhost.

## 4. Instalar voz a texto offline en español (Vosk)

Se utiliza **Vosk small es 0.42**, distribuido por Alpha Cephei, de unos **39 MB de descarga**. Reconoce voz en local y consume pocos recursos; es menos preciso que modelos grandes. Las grabaciones permanecen en el ordenador. Necesita **Python para Windows**, no hay dependencia de API.

1. Instala Python desde https://www.python.org/downloads/windows/ (habilita la opción de añadir Python al PATH si aparece).
2. Abre PowerShell **dentro de la carpeta raíz del proyecto**, en la que están `project.godot` y `voice`.
3. Ejecuta estos comandos uno por uno:

   ```powershell
   py -m venv .venv
   .\.venv\Scripts\python.exe -m pip install -r voice\requirements.txt
   .\.venv\Scripts\python.exe voice\download_model.py
   .\.venv\Scripts\python.exe voice\server.py
   ```

4. Deja **abierta** esa consola mientras juegas. Debe aparecer `Vosk listo en http://127.0.0.1:8765/health`.
5. En Godot, pulsa **Grabar voz**, habla, pulsa **Detener**; el audio se envía solo a `127.0.0.1:8765/transcribe`. El texto obtenido se utiliza como mensaje para el Pomi. La opción puede detenerse cuando quieras.

**Dónde se coloca Vosk:** el instalador lo guarda en `voice/models/vosk-model-small-es-0.42/`. Esa carpeta figura en `.gitignore`; los pesos del modelo **no se suben a GitHub**. El propio código `voice/download_model.py` sabe de dónde descargar el ZIP oficial cuando lo ejecutes.

Si deseas solo hablar por texto, no necesitas instalar el servicio de Vosk ni activar el micrófono.

## 5. Orden exacto de implementación

**Fase A — Primera vivienda (este ZIP):** arquitectura modular, diorama, navegación, necesidades, acciones, inventario limitado, guardado, Ollama opcional, Vosk opcional.

**Fase B — Calidad de la simulación:** observabilidad y depuración, rutas alrededor de muebles, acciones con duración, agenda diaria, recuerdos con procedencia, decisiones repetibles, autonomía y gestión de fallo de suministros.

**Fase C — Identidad artística:** preservar `Pomi_V05_LIGERO_MOVIL.bbmodel`; editar UV y paleta con colores planos semánticos (piel, cabello, ojos, pezones), sin sombras dibujadas, retirar ropa interior manteniendo anatomía neutra y añadir dedos low-poly separados; rigging y animaciones.

**Fase D — Social:** segundo Pomi solo después de estabilizar el primero; después Robi, economía compartida y finalmente ciudad-estado.

## 6. Limitaciones comprobadas y por comprobar

- Sí se han ejecutado: pruebas Python para conversión WAV, existencia de estructura y rutas locales (ver `docs/TEST_REPORT.md`).
- No se ha ejecutado: el editor/juego Godot en este entorno, ni el micrófono Windows, ni el modelo Ollama y Vosk reales; **no se promete que todo funcione sin errores**.
- El editor de personaje del antiguo prototipo 0.1.0 no está reutilizado. Se ha creado una base independiente para evitar su fallo de `ConfirmationDialog.get_vbox()`.
- La malla V05 original no tiene rig de animación; por ahora se desplaza como objeto rígido.
- Los consumibles (comida y agua) son finitos en esta demostración, no hay producción agrícola ni tiendas; eso pertenece a módulos futuros.
- Sin API remota ni conexión obligatoria a Internet después de instalar/descargar los modelos.

## 7. Archivos principales

`scenes/main.tscn`: escena inicial. `scripts/main.gd`: controlador/interfaz. `scripts/house.gd`: casa y muebles. `scripts/pomi_agent.gd`: avatar/rutas. `scripts/sim_state.gd`: necesidades, economía mínima y reglas. `scripts/ollama_bridge.gd`: LLM local. `scripts/voice_bridge.gd` + `voice/server.py`: voz local. `tests/`: pruebas. `docs/CANON.md`, `docs/ARCHITECTURE.md`, `docs/TEST_REPORT.md` y `docs/HANDOFF.md`: decisiones y transferencia.

## 8. Fuentes técnicas oficiales

- Godot AudioEffectRecord y micrófono: https://docs.godotengine.org/en/stable/tutorials/audio/recording_with_microphone.html
- Godot HTTPRequest: https://docs.godotengine.org/es/4.x/classes/class_httprequest.html
- Ollama API: https://docs.ollama.com/api
- Modelos Ollama: https://ollama.com/library/qwen3
- Vosk y licencia: https://alphacephei.com/vosk/models
