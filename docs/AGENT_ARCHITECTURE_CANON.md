# Teseracta — arquitectura cognitiva canónica Eko + Smallville

Estado: **propuesta arquitectónica; NO implementada**. 9 noviembre 2026.

## Intención

404 es un agente encarnado en un mundo simulado; no es simplemente un chatbot con una lista cerrada de movimientos. Debe nacer sabiendo quién es, qué cuerpo y receptores tiene, qué capacidades de actuación existen y cómo interpretar las señales disponibles. Su experiencia, conocimientos posteriores, decisiones, planes y opiniones deben ser propios y persistentes. Godot valida la física y no elige acciones voluntarias por el agente.

Referencias examinadas:
- Eko/Clawblox: https://machineplaying.org/paper/ y https://github.com/nacloos/clawblox
- Smallville/Generative Agents: https://arxiv.org/abs/2304.03442 y https://github.com/joonspk-research/generative_agents

Eko usa orquestación autónoma, herramientas de mundo, identidad SOUL, memoria episódica y semántica, un espacio de trabajo persistente y la capacidad de crear notas/programas. Smallville introduce percepción, recuperación de recuerdos, reflexión y planificación. Estos sistemas no son intercambiables: nuestra arquitectura debe combinar sus principios, no copiar archivos sueltos.

## 1. Conocimiento inicial y sus fuentes

**Identidad o SOUL:** nombre, punto de partida, rasgos iniciales opcionales, modo de comunicarse. En ZERO, 404 comienza sin biografía previa. No hay recuerdos falsos.

**SELF — esquema corporal generado automáticamente:** forma, posición, velocidad, tamaño, sentidos, límites y capacidades motrices reales. Cambiar el cuerpo modifica este esquema. Debe saber que tiene cuerpo virtual, no necesita que la persona se lo explique repetidamente.

**PHYSIOLOGY — manual de necesidades y sentidos generado automáticamente:** escalas, consecuencias y límites de hambre, cansancio, vejiga, salud, temperatura, contacto, etc., solo si el mundo las implementa. La versión ZERO aún NO tiene metabolismo. No permitir que el modelo finja sentir hambre si Godot no proporciona tal señal.

**TOOLS — manual de herramientas generado del mismo contrato que valida el mundo:** observar, MoveTo, Stop, Inspect, Use, parámetros y unidades, ejemplos correctos, qué informa una respuesta, cuándo puede fallar. Un único esquema tipado para validación y documentación, sin discrepancias entre código y prompt.

**WORLD BASICS — conocimiento general permitido:** significado de distancia, metros, superficies, objetos, obstáculos y acciones. No equivale a saber qué contiene una caja opaca, qué materiales están lejos o a identificar objetos que nunca ha percibido.

## 2. Percepción actual, no omnisciencia

El motor genera observaciones parciales según sensores reales: orientación, distancia, geometría, color en familias, oclusión, contacto, rugosidad, temperatura y sonidos, cuando existan dichos sensores. Distinguir siempre medidas del mundo, estimaciones y cosas desconocidas. No enviar propiedades ocultas por el simple hecho de que estén definidas en el editor.

La percepción actual no es memoria semántica ni autobiografía. Puede convertirse en episodio si el agente la considera relevante.

## 3. Memoria separada por propósito y procedencia

- EPISODIC_MEMORY: qué observó, intentó y qué ocurrió. Persistencia append-only, fecha/tick, procedencia y contexto. El diálogo no verifica una acción.
- SEMANTIC_MEMORY: conocimientos duraderos, hipótesis, errores, confianza y evidencia; el agente puede revisarlos cuando experiencias nuevas contradigan una conclusión anterior.
- PROCEDURAL_MEMORY: técnicas o secuencias reutilizables que ha descubierto mediante experimentos; un procedimiento no equivale a un movimiento corporal verificado.
- WORKING_MEMORY: conversación actual, intención activa, plan pendiente y resultados recientes. Temporal y acotado.
- AUTOBIOGRAPHICAL_MEMORY: hechos y preferencias de su identidad adquirida; inicialmente vacía.
- VERIFIED_WORLD_EVENTS: registro exclusivo de consecuencias que Godot ha confirmado. Ningún campo generado por el LLM puede falsificarlo.

El usuario puede inspeccionar y modificar memoria en el editor; toda intervención manual tiene una marca de procedencia distinta del conocimiento adquirido.

## 4. Arquitectura de un ciclo cognitivo

Evento relevante o iniciativa → Percepción → Recuperación de memoria → Interpretación/hipótesis → Selección de objetivo y/o acción por el modelo → Validación y ejecución física por Godot → Feedback verificable → Actualización de memorias y planes.

Las acciones pueden durar muchos ticks de simulación sin gastar tokens del LLM en cada fotograma. Los objetivos y planes deben sobrevivir a varias inferencias y ser interrumpibles. Si una acción falla, el fallo forma parte del aprendizaje; no ocultarlo ni detener artificialmente la IA.

El agente tiene libertad para explorar, quedarse quieto, hablar espontáneamente, hacer experimentos, fijarse metas o abandonarlas. No hay un guion que obligue a comer, dormir, caminar o hablar cada N segundos.

Una reflexión explícita puede guardarse y verse en el Inspector, pero no debe confundirse con el razonamiento oculto de un modelo ni con hechos confirmados.

## 5. Constructor de contexto, no un monolito

Antes de cada deliberación, ContextBuilder reúne las piezas correctas:

SYSTEM: identidad nuclear y reglas epistémicas.
BIRTH_KNOWLEDGE: esquema corporal, sentidos disponibles, manual de acciones y conocimientos generales de partida.
CURRENT_PERCEPTION: estado sensorial actual, con límites.
ACTIVE_STATE: objetivos, plan y errores pendientes.
MEMORIES: episodios relevantes más conocimiento semántico y procedimental seleccionado.
CONVERSATION: últimos turnos verdaderos de la persona y 404.
TOOLS: interfaces tipadas, generadas del motor.

El Inspector muestra **exactamente** lo que recibió el modelo, con tamaño y origen de cada parte. La base completa no entra en cada llamada: se recupera lo pertinente. Medir aciertos del modelo con Qwen 1.7B/3.5 2B, no afirmar que reproduzcan la capacidad de los agentes de programación muy grandes usados en Eko.

## 6. Ejemplo: contradicción sobre caminar

El cuerpo y el manual informan desde el nacimiento que puede solicitar MoveTo. Si el agente sospecha que no puede caminar, puede probar un movimiento. Godot verifica los metros recorridos (o explica por qué se bloqueó). El episodio se guarda; más adelante el agente puede comparar hipótesis con evidencia y revisar su conocimiento semántico. La conclusión no está fijada por código, y una afirmación verbal nunca se convierte por sí sola en realidad.

## 7. Editor e Inspector desde el primer núcleo

Pestañas previstas: objeto (dimensiones, material, color, transmisión, rugosidad, temperatura), cuerpo y sensores, identidad/SOUL, manual de capacidades (lectura del contrato del motor), percepción efectiva, memorias episódicas, semánticas y procedimentales, planes, conversaciones, acciones y sus verificaciones, reflexiones declaradas, contexto enviado al modelo y diagnósticos de inferencia. Las propiedades sensoriales solo se exponen al agente cuando son físicamente perceptibles.

## 8. Implementación incremental propuesta

A. **Contratos y auto-conocimiento:** esquema corporal y manual de herramientas generados desde Godot; ContextBuilder visible; pruebas de consistencia. Un cubo 404 y cubos editables.
B. **Memorias y evidencia:** almacenamiento distinguible de episodios, creencias y hechos; prueba automatizada de contradicción y revisión de hipótesis.
C. **Autonomía deliberativa:** estado de intención, planificación persistente, procesamiento por eventos y acciones largas independientes del ritmo del modelo.
D. **Fisiología real:** implementar sensores/órganos y sus consecuencias, y solo entonces enseñárselos al modelo mediante PHYSIOLOGY.
E. **Percepción espacial avanzada y socialización:** oclusión, línea de visión, aprendizaje espacial y múltiples Pomis, con prioridades de rendimiento.

### Lo que NO se hará como sustituto

- Suprimir frases repetidas en el chat o añadir pausas arbitrarias y llamarlo aprendizaje.
- Añadir una frase de prompt después de cada error como sustituto de un contrato autodescriptivo.
- Programar movimientos automáticos basados en necesidades como si fueran decisiones de 404.
- Inventar sensaciones que no tienen respaldo en el motor.
- Entregar a 404 la base de datos completa de objetos como si fueran observaciones sensoriales.
- Confundir memoria conversacional, hipótesis, intención y hecho verificado.
- Declarar que un modelo de 1.7B ejecuta el experimento completo de Eko sin una comparación medible.

**Esta especificación sustituye el enfoque de parches conversacionales. No significa que los módulos propuestos estén implementados.**
