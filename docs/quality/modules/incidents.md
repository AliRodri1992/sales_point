# Incidencias

## Alcance

Footer del dashboard, alta, lista personal, bandeja de organización para soporte y administradores, detalle, descarga de evidencia y seguimiento administrativo dentro de la organización activa. El formulario abre una pestaña independiente para preservar la operación de origen. El folio comparte una secuencia diaria entre organizaciones y usa la zona horaria global configurada en Rails.

## Integración con GitHub

Instalar la GitHub App en AliRodri1992/sales_point con permiso Issues de escritura. Configurar INCIDENT_GITHUB_APP_ID, INCIDENT_GITHUB_INSTALLATION_ID, INCIDENT_GITHUB_PRIVATE_KEY y DELTA_POS_URL en el entorno del worker y de Rails. Guardar la clave PEM en el gestor de secretos del despliegue. El worker usa tokens de instalación temporales. Los datos libres, referencias operativas y archivos permanecen en Delta POS.

Los reportes pendientes se pueden reencolar con `bin/rails incidents:sync`. Si un envío quedó en estado sending y el job agotó los reintentos, comprobar primero el folio en GitHub. El job busca el issue antes de enlazarlo. Restablecer a pending únicamente después de confirmar que GitHub no creó el issue.

## Estado

NO CERRADO. PENDIENTE verificar RSpec, navegador, despliegue y credenciales de la instalación.
