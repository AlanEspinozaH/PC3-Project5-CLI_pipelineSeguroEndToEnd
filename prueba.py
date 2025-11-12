from src.adapters.age_secrets_adapter import AgeSecretsAdapter

secrets_file = "secrets.v1.age"
identity_file = "secrets/age-identities.txt"

adapter = AgeSecretsAdapter(secrets_file, identity_file)

try:
    secret_value = adapter.get("SIGN_SEED")
    print(f"El valor de SIGN_SEED es: {secret_value}")
except Exception as e:
    print(f"Error al desencriptar el secreto: {e}")
