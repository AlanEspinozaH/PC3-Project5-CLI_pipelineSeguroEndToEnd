current_version=$(readlink secrets.current.age | sed 's/secrets.v//')

next_version=$((current_version + 1))
new_kek_id="local-$(date +%Y%m%d)"

age -r $(cat secrets/age-identities.txt) -o secrets.v${next_version}.age secrets.json

ln -sf secrets.v${next_version}.age secrets.current.age

echo "Rotación completada: secretos.v${next_version}.age creado y symlink actualizado a secrets.current.age"

