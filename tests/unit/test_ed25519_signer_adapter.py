from unittest.mock import Mock

# Importa la clase que AÚN NO EXISTE
from src.adapters.ed25519_signer_adapter import Ed25519SignerAdapter
from src.ports.secrets_port import SecretsPort

# Esta es la "semilla" (seed) falsa que fingiremos que viene de SecretsPort
FAKE_SEED_B64 = "YcR8q/v3Yen4nCwnFL+lTf/xI4S6A+l+LUmz2hS+TPA="


def test_signer_roundtrip():
    """
    Prueba el "viaje de ida y vuelta":
    1. Firma un payload.
    2. Verifica la firma con la clave pública.
    """
    # 1. Arrange (Preparar)
    # ¡Aquí está el truco anti-bloqueo!
    # Creamos un MOCK (un doble) de SecretsPort.
    mock_secrets_port = Mock(spec=SecretsPort)
    # Configuramos el mock para que devuelva nuestra semilla falsa
    mock_secrets_port.get.return_value = FAKE_SEED_B64

    # Inyectamos el mock en nuestro adapter
    # Nota: El adapter AÚN NO EXISTE, pero así es como TDD funciona
    signer = Ed25519SignerAdapter(secrets_port=mock_secrets_port)

    payload = b"Este es el payload de la boleta"

    # 2. Act (Actuar)
    public_key = signer.public_key()
    signature = signer.sign(payload)

    # 3. Assert (Verificar)
    # Verificamos que se usó el mock
    mock_secrets_port.get.assert_called_with("SIGN_SEED")

    # Verificamos los formatos de salida
    assert isinstance(public_key, bytes) and len(public_key) == 32
    assert isinstance(signature, bytes) and len(signature) == 64

    # Verificamos que la firma es válida
    assert signer.verify(payload, signature)

    # Verificamos que una firma mala falla
    assert not signer.verify(b"otro payload", signature)
