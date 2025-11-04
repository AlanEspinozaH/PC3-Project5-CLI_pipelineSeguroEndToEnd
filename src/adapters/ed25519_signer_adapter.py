import base64

from nacl.signing import SigningKey

from src.ports.secrets_port import SecretsPort
from src.ports.signer_port import SignerPort


class Ed25519SignerAdapter(SignerPort):
    """
    Implementación del SignerPort usando la librería PyNaCl
    para criptografía de curva elíptica Ed25519.
    """

    def __init__(self, secrets_port: SecretsPort):
        # Obtenemos la semilla (seed) de 32 bytes del
        # SecretsPort (que está mockeado en los tests).
        #
        seed_b64 = secrets_port.get("SIGN_SEED")
        seed_bytes = base64.b64decode(seed_b64)

        # Generamos la clave de firma a partir de la semilla
        self._signing_key = SigningKey(seed=seed_bytes)

    def public_key(self) -> bytes:
        """Devuelve la clave pública de 32 bytes"""
        return bytes(self._signing_key.verify_key)

    def sign(self, payload: bytes) -> bytes:
        """Firma un payload y devuelve la firma de 64 bytes"""
        signed = self._signing_key.sign(payload)
        return signed.signature

    def verify(self, payload: bytes, signature: bytes) -> bool:
        """Verifica una firma contra un payload"""
        try:
            # Usamos la clave de verificación (pública)
            verify_key = self._signing_key.verify_key
            verify_key.verify(payload, signature)
            return True
        except Exception:
            return False
