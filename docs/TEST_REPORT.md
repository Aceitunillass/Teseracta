# Informe de pruebas — 9 noviembre 2026

**Entorno actual:** Python disponible; Godot no detectado en PATH. No se ha instalado/ejecutado Godot ni Ollama ni Vosk en este entorno. No confundir validación estática con prueba integral.

## Ejecutado

`python -m unittest discover -s tests -v`: 8/8 pruebas superadas.

- Estructura de archivos requerida: OK.
- Presencia del GLB original del modelo canónico: OK.
- Servicios locales por localhost y carpetas de modelos ignoradas en Git: OK.
- WAV a PCM mono 16k: 44.1 kHz estéreo, 16 kHz mono, 22.05 kHz 8 bit: OK.
- WAV inválido rechazado: OK.

## Sin comprobar

- Importación del proyecto en Godot 4.7.2, parseo y ejecución de GDScript.
- Compatibilidad visual/animación del GLB en Godot; Blockbench no tiene validación de su `.bbmodel` aquí.
- Navegación real por habitaciones, raycasts en muebles y botón pause.
- Conversaciones Ollama con Qwen3 1.7B y calidad de las respuestas en el hardware del usuario.
- Grabación de audio real desde micrófono Windows y conexión Vosk.
- Rendimiento CPU/GPU/RAM; estabilidad a largo plazo y migración de guardados.

## Próxima validación en el PC del usuario

1. Importar `project.godot` en Godot; anotar el primer error rojo de `Output`/`Debugger`.
2. Hacer clic en los cinco tipos de muebles y comprobar consumos y necesidades.
3. Guardar, reiniciar y cargar, comprobar estado persistido.
4. Abrir PowerShell y verificar que Ollama responde con `ollama run qwen3:1.7b`.
5. Iniciar Vosk y probar `http://127.0.0.1:8765/health`.
6. Probar micrófono, registros de errores, tasas de FPS y latencia de IA.
