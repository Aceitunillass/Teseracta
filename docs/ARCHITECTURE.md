# TESERACTA ZERO — arquitectura inicial

Versión experimental reiniciada desde cero. El antiguo código y los recursos visuales NO forman parte del árbol actual. No se importa ningún recuerdo ni identidad anterior. El historial Git previo puede seguir accesible por ser el mismo repositorio; esto no equivale a borrar el repositorio de GitHub.

## Referencias investigadas

- [Clawblox / Eko](https://github.com/nacloos/clawblox): mundo independiente con protocolo api.md, join, observe, input, acciones MoveTo y Stop, registros y snapshots. En este primer vertical slice copiamos la separación conceptual, no el motor, ni sus scripts, ni desplegamos todavía su servidor HTTP. Nuestra interfaz local es world.action_api(), world.observe(), world.submit_action().
- [AI Town](https://github.com/a16z-infra/ai-town): agentes con estado individual y simulación compartida.
- [Concordia](https://github.com/google-deepmind/concordia): separación de agentes y árbitro del mundo.
- [Generative Agents](https://github.com/joonspk-research/generative_agents): recuerdos y contexto episódico; ningún aprendizaje cognitivo complejo se ha implementado todavía.

## Módulos

1. scripts/world.gd: autoridad física independiente del LLM. Simulación fija por ticks de 100 ms; objetos, sensores de proximidad y acciones verificadas. Sin locomoción guionizada por necesidades.
2. scripts/brain.gd: cliente Ollama local asíncrono; recibe una observación y propone a lo sumo una acción en cada inferencia. Streaming visual del campo speech. El motor debe aceptar o rechazar cada acción.
3. scripts/memory.gd: nueva carpeta de usuario exclusiva user://teseracta_zero/; prompt editable, memoria editable, eventos físicos en registro independiente y nuevo estado del mundo. No consulta rutas V1/V2.
4. scripts/main.gd: render 3D low-poly y UI. Editor de objetos por cubos, prompt, modelo, recuerdos, conversación y depuración. La UI no decide las acciones del agente.
5. Pruebas CI: estructura con Python, importación real y arranque corto en Godot 4.7.2 con la compilación oficial verificada.

## Interacción del modelo

Modelo local configurable, por defecto qwen3:1.7b. El agente lee action_api, observe, recuerdos seleccionados y eventos verificables. Propone un comando de tipo y datos:

- MoveTo: position=[x,z]; Godot comprueba límites y posición final libre; la trayectoria recta todavía no esquiva obstáculos intermedios.
- Stop: cancela movimiento.
- Inspect: id=obj_1; se limita a objetos en rango.
- Use: id=food; exige proximidad; en ZERO no existe metabolismo.
- Wait: sin acción corporal.

La IA puede encadenar decisiones en ciclos independientes, pero no se realiza inferencia por cada tick. No se asegura concurrencia generativa para varios agentes en el portátil.

## Editor de objetos

Funciona dentro de Godot: añadir/borrar cubos y configurar nombre, posición, dimensiones, paleta cromática, material, rugosidad, temperatura y transmisión visual. Estado guardado en user://teseracta_zero/world.json. Paredes fijas por ahora. Estas propiedades son datos de mundo: el receptor solo ve una familia cromática simplificada; rugosidad, material y temperatura se perciben al estar cerca. Transparencia visual solo se representa gráficamente; no se rastrea contenido a través de cristal todavía.

## Limitaciones honestas del MVP

- Percepción espacial por distancia, sin orientación visual, raycasts/oclusiones, temperatura aparente ni aprendizaje de categorías.
- Solo un Pomi-cubo y tres cubos editables, paredes fijas, sin animaciones ni locomoción con pathfinding.
- Las interacciones de comida/descanso/aseo son placeholders: no hay simulación fisiológica.
- No hay servidor HTTP compatible con Clawblox aún: se utiliza una interfaz equivalente interna en Godot.
- Las notas reflection son declaraciones generadas por el modelo, no acceso a pensamiento oculto.
- Las memorias manualmente editadas se marcan como tales; no sustituyen el registro separado de hechos del motor.
- El guardado de mundo restaura objetos y posición, no hay snapshots completos de sesión de inferencia.
- Ejecutar Godot CI verifica importación y arranque breve, no conversación real con Ollama ni la usabilidad manual del editor.

## Próximas pruebas de aceptación

1. Compilar Godot sin errores; abrir la escena.
2. Añadir un cubo rosa y cambiar color, material y dimensiones; guardar y reabrir.
3. Cambiar prompt/modelo y comprobar que persisten.
4. Comenzar con memoria vacía; conversar y editar recuerdos con JSON válido; reiniciar.
5. Dejar que 404 proponga MoveTo y ver eventos move_started / move_completed medidos por el motor.
6. Solicitar Stop, Inspect, Use; probar rechazos fuera de rango.
7. Verificar que Registro muestra acciones propuestas y reflexiones explícitas sin mezclarlas con hechos del mundo.
8. Medir tokens por segundo antes de añadir otro agente.
