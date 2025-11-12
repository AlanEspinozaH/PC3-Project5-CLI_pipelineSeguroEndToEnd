from src.adapters.age_secrets_adapter import AgeSecretsAdapter


def test_version(monkeypatch, tmp_path):
    (tmp_path / "secrets.v3.age").write_text("{}")
    (tmp_path / "secrets.current.age").symlink_to(tmp_path / "secrets.v3.age")
    adapter = AgeSecretsAdapter(secrets_file=tmp_path / "secrets.current.age")
    assert adapter.version() == "v3"
