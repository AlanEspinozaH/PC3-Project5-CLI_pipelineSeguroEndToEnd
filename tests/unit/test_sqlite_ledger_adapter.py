import hashlib

import pytest

# Importa la clase que AÚN NO EXISTE
from src.adapters.sqlite_ledger_adapter import SQLiteLedgerAdapter
from src.ports.ledger_port import Receipt


# Esta es una fixture de pytest. 'tmp_path' crea un directorio
# temporal único para esta prueba, asegurando que cada
# [cite_start]prueba tenga una base de datos limpia. [cite: 7]
@pytest.fixture
def temp_db_path(tmp_path):
    db_file = tmp_path / "test_ledger.db"
    return str(db_file)


def test_ledger_chaining(temp_db_path):
    """
    Prueba que el ledger encadene los hashes correctamente.
    1. Apendiza un 'genesis' (primera boleta).
    2. Apendiza una segunda boleta.
    3. Verifica que el prev_hash de la 2da sea el hash de la 1ra.
    """
    # 1. Arrange
    adapter = SQLiteLedgerAdapter(db_path=temp_db_path)
    adapter.connect()  # Asegura que la tabla esté creada

    # Datos de la primera boleta (genesis)
    r1 = Receipt(
        id="uuid-1",
        payload=b'{"total": 10}',
        signature=b"sig1",
        prev_hash=None,
        hash="",
        created_at="...T1",
    )

    # 2. Act (Genesis)
    adapter.append(r1)

    # 3. Assert (Genesis)
    assert r1.prev_hash is None  # El primer hash previo es None
    # El hash debe haber sido calculado por el adapter
    assert r1.hash == hashlib.sha256(b'{"total": 10}' + b"sig1").hexdigest()

    last_hash_db = adapter.get_last_hash()
    assert last_hash_db == r1.hash

    # --- Segunda Boleta ---

    # 4. Arrange (Boleta 2)
    r2 = Receipt(
        id="uuid-2",
        payload=b'{"total": 20}',
        signature=b"sig2",
        prev_hash=None,
        hash="",
        created_at="...T2",
    )

    # 5. Act (Boleta 2)
    adapter.append(r2)

    # 6. Assert (Boleta 2)
    # El adapter debe haber detectado el prev_hash automáticamente
    assert r2.prev_hash == r1.hash

    # El nuevo hash se calcula sobre la cadena
    expected_hash2 = hashlib.sha256(
        r1.hash.encode("utf-8") + b'{"total": 20}' + b"sig2"
    ).hexdigest()
    assert r2.hash == expected_hash2
    assert adapter.get_last_hash() == r2.hash

    # Prueba final de integridad
    assert adapter.verify_chain()

    adapter.close()
