# CFDI 4.0 signature stylesheet

This directory contains an offline, self-contained compilation of the SAT CFDI 4.0 cadena-original stylesheet, with SAT utility and Pagos 2.0 templates inlined. No network stylesheet resolution occurs while validating invoices.

Normative source: http://www.sat.gob.mx/sitio_internet/cfd/4/cadenaoriginal_4_0/cadenaoriginal_4_0.xslt
The stylesheets were obtained from https://github.com/cmendezs/mcp-cfdi-mx/tree/main/src/mcp_cfdi_mx/resources on 2026-10-24 and kept in their original template order.

**Scope:** core CFDI 4.0, SAT digital stamp (excluded from the issuer cadena), and Pagos 2.0. Other complement namespaces are explicitly rejected by `AccountsPayable::CfdiSignatureVerifier` rather than silently ignored.

For production, configure `SAT_CSD_TRUST_STORE` to a locally mounted PEM trust store containing SAT-authorized certificate issuers. Do not commit certificates or private keys here. Refresh the stylesheet and issuer trust store as SAT publishes updates; verify representative signed real CFDI before enabling posting.
