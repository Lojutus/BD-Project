# `problema pgadmin/`
Si al ingresar a pgadmin el cuenta y/o la contraseña es diferente de **biblioteca** los siguientes comandos pueden solucionar el problema:
```bash
docker compose down -v --remove-orphans
if (Test-Path .\postgres\data\pgdata) {
    Remove-Item -Recurse -Force .\postgres\data\pgdata
}
docker compose up -d --force-recreate
```