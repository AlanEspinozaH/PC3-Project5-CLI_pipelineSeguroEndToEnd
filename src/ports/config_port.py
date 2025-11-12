# src/ports/config_port.py
from dataclasses import dataclass


@dataclass
class Config:
    app_env: str
    db_url: str
    ledger_path: str
    secrets_file: str


class ConfigPort:
    def load(self) -> Config: ...
