import json
import os
import subprocess

from src.ports.secrets_port import SecretsPort
class AgeSecretsAdapter(SecretsPort):
    def __init__(
        self,
        secrets_file="secrets/secrets.current.age",
        identity_file="secrets/age-identities.txt",
    ):
        self.secrets_file = secrets_file
        self.identity_file = identity_file

    def version(self) -> str:
        real_path = os.path.realpath(self.secrets_file)
        base = os.path.basename(real_path)
        return base.split(".")[1]

    def read_all(self) -> dict[str, str]:
        try:
            result = subprocess.run(
                ["age", "-d", "-i", self.identity_file, "-o", "-", self.secrets_file],
                check=True,
                capture_output=True,
            )
            data = json.loads(result.stdout.decode())
            return data
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"Error al desencriptar secretos: {e.stderr.decode()}")
        except json.JSONDecodeError:
            raise ValueError("El contenido del archivo .age no es un JSON válido")

    def get(self, name: str) -> str:
        data = self.read_all()
        try:
            return data["secrets"][name]
        except KeyError:
            raise KeyError(f"Secreto '{name}' no encontrado en el archivo .age")
