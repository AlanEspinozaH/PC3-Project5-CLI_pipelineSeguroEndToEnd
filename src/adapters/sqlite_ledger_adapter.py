# src/adapters/sqlite_ledger_adapter.py
import hashlib
import sqlite3
from typing import Optional

from src.ports.ledger_port import LedgerPort, Receipt


class SQLiteLedgerAdapter(LedgerPort):
    """
    Implementación del LedgerPort usando SQLite.
    Mantiene una cadena de hashes para asegurar la integridad (inmutabilidad).
    """

    def __init__(self, db_path: str):
        self.db_path = db_path
        self.connection: Optional[sqlite3.Connection] = None

    def connect(self):
        """Establece la conexión y crea la tabla."""
        self.connection = sqlite3.connect(self.db_path)
        self._create_table()

    def close(self):
        if self.connection:
            self.connection.close()

    def _create_table(self):
        """Crea la tabla de boletas si no existe"""
        sql = """
        CREATE TABLE IF NOT EXISTS receipts(
          id TEXT PRIMARY KEY,
          payload BLOB NOT NULL,
          signature BLOB NOT NULL,
          prev_hash TEXT,
          hash TEXT NOT NULL UNIQUE,
          created_at TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_receipts_hash ON receipts(hash);
        """
        with self.connection:
            self.connection.executescript(sql)

    def get_last_hash(self) -> Optional[str]:
        """Obtiene el hash del último registro insertado"""
        if not self.connection:
            self.connect()
        sql = "SELECT hash FROM receipts ORDER BY rowid DESC LIMIT 1"
        with self.connection:
            cursor = self.connection.execute(sql)
            result = cursor.fetchone()
            return result[0] if result else None

    def append(self, r: Receipt) -> None:
        """Añade una nueva boleta, calculando su hash encadenado"""
        if not self.connection:
            self.connect()

        # 1. Obtener el hash previo
        prev_hash = self.get_last_hash()
        r.prev_hash = prev_hash  # Actualiza el objeto

        # 2. Calcular el hash de la boleta actual
        # hash = sha256(prev_hash||payload||signature)
        hasher = hashlib.sha256()
        if prev_hash:
            hasher.update(prev_hash.encode("utf-8"))
        hasher.update(r.payload)
        hasher.update(r.signature)
        r.hash = hasher.hexdigest()

        # 3. Insertar transaccionalmente
        sql = """
        INSERT INTO receipts (id, payload, signature, prev_hash, hash, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """
        try:
            with self.connection:
                self.connection.execute(
                    sql,
                    (r.id, r.payload, r.signature, r.prev_hash, r.hash, r.created_at),
                )
        except sqlite3.IntegrityError as e:
            raise ValueError(f"Error de integridad, hash duplicado? {e}")

    def verify_chain(self) -> bool:
        """Recalcula y verifica toda la cadena de hashes"""
        if not self.connection:
            self.connect()

        sql = "SELECT payload, signature, prev_hash, hash FROM receipts ORDER BY rowid ASC"
        with self.connection:
            cursor = self.connection.execute(sql)
            last_valid_hash: Optional[str] = None

            for row in cursor.fetchall():
                payload, signature, prev_hash_db, hash_db = row

                # Verifica que el prev_hash coincida con el hash anterior
                if prev_hash_db != last_valid_hash:
                    return False  # Cadena rota

                # Recalcula el hash
                hasher = hashlib.sha256()
                if prev_hash_db:
                    hasher.update(prev_hash_db.encode("utf-8"))
                hasher.update(payload)
                hasher.update(signature)
                calculated_hash = hasher.hexdigest()

                # Verifica que el hash recalculado coincida
                if calculated_hash != hash_db:
                    return False  # Datos alterados

                # Avanza al siguiente eslabón
                last_valid_hash = calculated_hash

            return True  # Si el bucle termina, la cadena está íntegra
