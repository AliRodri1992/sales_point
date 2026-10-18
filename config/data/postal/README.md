# Catálogo postal local de México

Fuente de los datos: Servicio Postal Mexicano (SEPOMEX), catálogo nacional de códigos postales; se tomó la versión publicada por IcaliaLabs en https://github.com/IcaliaLabs/sepomex/blob/main/lib/sepomex_db.csv (consultada el 18-10-2026), derivada del catálogo oficial de Correos de México: https://www.correosdemexico.gob.mx/SSLServicios/ConsultaCP/CodigoPostal_Exportar.aspx.

Diez archivos JSON ordenados por primer dígito del código postal. Cada clave de 5 dígitos contiene `[estado, municipio, [colonias...]]`. Incluye los 32 estados y 31,878 códigos postales (el archivo fuente registraba 158,864 asentamientos). Todos los campos son geografía pública; no contienen datos personales.

Antes de redistribuir los datos en un producto comercial, verificar las condiciones vigentes del catálogo oficial. No comercializar el catálogo como producto independiente. Actualizar estos archivos de manera reproducible cuando SEPOMEX publique una nueva versión.
