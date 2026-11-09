"""Descarga bajo demanda el modelo oficial de Vosk en español. No se sube a GitHub."""
from pathlib import Path
from urllib.request import urlopen
import shutil
import zipfile

NAME = "vosk-model-small-es-0.42"
URL = f"https://alphacephei.com/vosk/models/{NAME}.zip"
DEST = Path(__file__).parent / "models"
TARGET = DEST / NAME


def download() -> None:
    if (TARGET / "conf").exists():
        print("El modelo ya existe:", TARGET)
        return
    DEST.mkdir(parents=True, exist_ok=True)
    archive = DEST / f"{NAME}.zip"
    if not archive.exists():
        print("Descargando ~39 MB del sitio oficial de Vosk...")
        with urlopen(URL, timeout=180) as src, archive.open("wb") as dst:
            shutil.copyfileobj(src, dst)
    with zipfile.ZipFile(archive) as zf:
        # Protección contra zip-slip y archivos fuera de la carpeta autorizada.
        for entry in zf.infolist():
            path = Path(entry.filename)
            if path.is_absolute() or ".." in path.parts or path.parts[0] != NAME:
                raise ValueError("Entrada ZIP fuera del directorio del modelo")
        zf.extractall(DEST)
    if not (TARGET / "conf").exists():
        raise RuntimeError("El ZIP descargado no tiene la estructura esperada")
    archive.unlink(missing_ok=True)
    print("Modelo Vosk descargado en:", TARGET)


if __name__ == "__main__":
    download()
