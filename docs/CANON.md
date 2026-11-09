# Canon actualizado — 2026-11-09

- Mundo: **Teseracta**, futura ciudad-estado cyberpunk kawaii.
- Población futura: Pomis; robots Robis. **Prototipo actual: un solo Pomi** y su vivienda, no cinco todavía.
- Estética adoptada: **3D low-poly anime** con cámara **isométrica ortográfica**, no pixel art 2.5D. Las texturas deben ser **colores planos semánticos** (piel, ojos, cabello, pezones, accesorios), **sin sombras pintadas ni degradados**. Los materiales se muestran unshaded en esta fase.
- **Modelo canónico:** `Pomi_V05_LIGERO_MOVIL.bbmodel`. Mantener silueta y proporciones. Su `.glb` derivado usado en Godot no sustituye el archivo maestro. No rediseñar de cero.
- **Pomi V06 visual pendiente:** eliminar calzoncillo, anatomía neutra sin genitales explícitos, separar dedos muy lowpoly, recolorizar atlas sin falsas sombras, mantener geometría que el usuario ya ha aprobado.
- Primera vivienda: dormitorio, baño, cocina y salón. Probar navegación, objetos, necesidades, personalidad, autonomía, conversación, voz y memoria antes de ampliar la ciudad.
- Simulación propietaria independiente del LLM. El LLM solo formula respuestas/propuestas, nunca modifica directamente el mundo.
- IA sin API de pago ejecutada localmente en Windows. Asignar presupuestos de CPU/RAM. Mantener modo texto funcional cuando la IA no esté disponible.
- Godot destino declarado: 4.7.2 stable, sin pruebas sobre esa versión en este entorno.
- Primera versión: sin niños, política emergente, Robis, economía urbana ni otros Pomis. Estos módulos posteriores deberán ser extensibles.
