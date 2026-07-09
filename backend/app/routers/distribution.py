from io import BytesIO
from pathlib import Path
from urllib.parse import quote_plus

import qrcode
from fastapi import APIRouter, HTTPException, Request
from fastapi.responses import FileResponse, HTMLResponse, Response


router = APIRouter(prefix="/distribution")

_BACKEND_ROOT = Path(__file__).resolve().parents[2]
_PUBLIC_DIR = _BACKEND_ROOT / "public"
_APK_FILE_NAME = "app-release.apk"


def _apk_path() -> Path:
    return _PUBLIC_DIR / _APK_FILE_NAME


@router.get("/apk", name="download_apk")
def download_apk() -> FileResponse:
    apk = _apk_path()
    if not apk.exists():
        raise HTTPException(
            status_code=404,
            detail=(
                "APK file not found. Upload it to backend/public/app-release.apk "
                "on the server."
            ),
        )
    return FileResponse(
        path=apk,
        media_type="application/vnd.android.package-archive",
        filename=_APK_FILE_NAME,
    )


@router.get("/qr.png", name="distribution_qr_png")
def distribution_qr_png(request: Request, target_url: str | None = None) -> Response:
    download_url = str(request.url_for("download_apk"))
    qr_target = target_url or download_url

    qr_img = qrcode.make(qr_target)
    buf = BytesIO()
    qr_img.save(buf, format="PNG")

    return Response(content=buf.getvalue(), media_type="image/png")


@router.get("/landing", name="distribution_landing", response_class=HTMLResponse)
def distribution_landing(request: Request) -> HTMLResponse:
    download_url = str(request.url_for("download_apk"))
    qr_url = f"{request.url_for('distribution_qr_png')}?target_url={quote_plus(download_url)}"

    html = f"""<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>PHC APK Download</title>
  <style>
    body {{
      margin: 0;
      background: #0f172a;
      color: #e2e8f0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
    }}
    .wrap {{
      max-width: 820px;
      margin: 40px auto;
      padding: 24px;
    }}
    .card {{
      background: #111827;
      border: 1px solid #1f2937;
      border-radius: 16px;
      padding: 24px;
      text-align: center;
    }}
    h1 {{ margin-top: 0; font-size: 28px; }}
    p {{ color: #cbd5e1; }}
    img {{
      margin-top: 16px;
      border-radius: 12px;
      background: white;
      padding: 12px;
      width: min(320px, 80vw);
      height: auto;
    }}
    a.btn {{
      display: inline-block;
      margin-top: 20px;
      padding: 12px 18px;
      border-radius: 10px;
      background: #2563eb;
      color: white;
      text-decoration: none;
      font-weight: 600;
    }}
    .meta {{
      margin-top: 18px;
      font-size: 13px;
      color: #94a3b8;
      word-break: break-all;
    }}
  </style>
</head>
<body>
  <div class="wrap">
    <div class="card">
      <h1>Personal Health Consultant</h1>
      <p>Сканируйте QR-код, чтобы скачать APK на телефон.</p>
      <img src="{qr_url}" alt="QR code for APK download">
      <div>
        <a class="btn" href="{download_url}">Скачать APK</a>
      </div>
      <div class="meta">{download_url}</div>
    </div>
  </div>
</body>
</html>
"""
    return HTMLResponse(content=html)
