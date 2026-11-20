# Iconografía SVG inline original

- Los iconos de UI deben estar escritos como código `<svg>` directamente en HTML/ERB renderizado; se admite un parcial ERB o ViewComponent que emita ese mismo SVG inline.
- Diseñar trazados originales, no copiar paths de Lucide, Heroicons u otras librerías; no añadir paquetes de iconos, fuentes de iconos ni CDN.
- Base sugerida por icono: `viewBox="0 0 24 24"`, `fill="none"`, `stroke="currentColor"`, `stroke-width="1.8"`, `stroke-linecap="round"`, `stroke-linejoin="round"`. Ajustar al diseño real, sin imponer idéntica geometría a todos.
- Para iconos decorativos: `aria-hidden="true"` y `focusable="false"`; para botón solo-icono, poner `aria-label` significativo **en el botón**.
- Asegurar área táctil apropiada, estados focus-visible y contraste con Delta Emerald; no transmitir estados solo por color.
- Evitar SVG externo para iconos de interfaz; los logos/favicons o arte de mascota son recursos diferentes y no se convierten automáticamente a inline.

## Ejemplo ERB (icono propio de caja)
```erb
<button type="button" aria-label="<%= t('inventory.open') %>" class="inline-grid min-h-11 min-w-11 place-items-center rounded-lg text-[var(--brand-on-white)] focus-visible:outline-2 focus-visible:outline-offset-2">
  <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">
    <path d="M4 7.5 12 3.5l8 4v9l-8 4-8-4z" />
    <path d="m4 7.5 8 4 8-4M12 11.5v9" />
    <path d="M8.5 5.25 16.5 9.25" />
  </svg>
</button>
```
El ejemplo es ilustrativo: comprobar la clave i18n real antes de usarla.
