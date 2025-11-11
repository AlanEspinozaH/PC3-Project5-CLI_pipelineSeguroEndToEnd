# src/ports/ledger_port.py
from dataclasses import dataclass


@dataclass
class Receipt:
    id: str  # uuid4
    payload: bytes  # JSON bytes de la boleta
    signature: bytes  # Ed25519
    prev_hash: str  # hex
    hash: str  # hex (SHA-256 de prev_hash||payload||signature)
    created_at: str  # ISO-8601 (ClockPort)


class LedgerPort:
    def append(self, r: Receipt) -> None: ...
    def get_last_hash(self) -> str | None: ...
    def verify_chain(self) -> bool: ...  # True si cadena íntegra
