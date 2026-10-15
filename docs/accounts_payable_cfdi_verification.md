# CFDI 4.0 verification deployment requirements

The system intentionally rejects posting CFDI invoices if any required trust asset is unavailable.

1. Obtain the SAT-published CFDI 4.0 cadena-original XSLT package from the official SAT website:
   https://wwwmat.sat.gob.mx/cs/Satellite?c=ConsultaInfo&childpagename=SatTyR%2FConsultaInfo%2FSAT_LandingConsultaInformacion&cid=1462241943074&packedargs=d%3DTouch&pagename=TySWrapper
2. Verify package authenticity, preserve the original XSLT and every imported dependency, and install under `config/sat/` with the entrypoint named `cadenaoriginal_4_0.xslt`. Do not permit runtime network resolution of XSLT includes.
3. Obtain verified SAT certificate trust anchors; configure `SAT_CSD_TRUST_STORE` as an absolute path to a PEM bundle.
4. Maintain and validate the SAT Lista de Contribuyentes Obligados (LCO) for the issuer RFC and CSD serial. The basic X.509 trust check in this repository does **not** establish LCO membership or non-revocation.
5. Test valid, altered, expired, revoked, and unknown-authority samples against real SAT-issued CFDI 4.0, in addition to unit tests with synthetic certificates.

**Deployment must remain blocked** until the official XSLT package, SAT certificate chain, and LCO validation have been verified end-to-end. A successful RSA signature check alone is not proof of SAT issuance.
