# Delta Emerald — referencia visual verificada en código

## Fuentes de verdad
- `app/assets/stylesheets/components/themes.css`: `.theme-delta-emerald` define `--brand: #059669`, `--brand-on-white: #047857`, `--brand-light: #d1fae5`.
- `app/assets/stylesheets/application.tailwind.css`: Tailwind CSS 4; `--font-sans: Inter, Plus Jakarta Sans` y `--font-jakarta: Plus Jakarta Sans, Inter`; `.input-field:focus` y `.btn-submit-dynamic` consumen tokens `--brand`.
- `app/assets/stylesheets/fonts.css`: fuentes locales Inter variable 400–700 y Plus Jakarta Sans 600–800, con `font-display: swap`.
- `app/views/layouts/application.html.erb`: fondo `bg-slate-50`, texto `text-slate-600`, selección `emerald-600`.
- `app/assets/stylesheets/components/categories_workspace.css`: encabezados, filtros, tablas, botones, modales y estados responsive del catálogo.
- `app/assets/stylesheets/components/branch_workspace.css`: formularios y listados de sucursales, validación y responsive.

## Semántica y límites
- Delta Emerald es la identidad del sistema; no confundir con `.theme-emerald-green` (`--brand: #10b981`) ni imponer Delta Emerald a la funcionalidad de temas configurables.
- Preferir `var(--brand)`, `var(--brand-on-white)` y `var(--brand-light)` en superficies tematizables; los hex citados son evidencia, no licencia para duplicarlos indiscriminadamente.
- Superficies observadas: blanco `#fff`, `#f8fafc` y bordes `#e2e8f0`; texto oscuro `#0f172a`, secundario `#475569`/`#64748b`. Son patrones existentes, no tokens globales nuevos.
- Usar encabezados Plus Jakarta Sans y texto Inter según componentes existentes; jerarquía, alineación y espaciado deben ser consistentes.
- Diseño profesional, actual, elegante, sobrio, sin saturación de tarjetas, sombras ni degradados.
- Validar contraste de combinaciones efectivamente renderizadas antes de aprobarlas; no asumir WCAG AA por pertenecer a la paleta.

## Auditoría inicial — alcance y evidencia
Inspección **estática** de los archivos anteriores en la rama de trabajo. Se confirmó que conviven temas alternativos, valores emerald y algunos acentos azules en estilos de dashboard. **No se verificó** cuál tema aplica a cada usuario en ejecución, ni se realizó auditoría visual con navegador. Cualquier propuesta de unificación requiere revisar vistas, preferencias de tema y capturas reales antes de cambiar estilos.
