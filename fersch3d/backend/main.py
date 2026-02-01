"""
Entry point for the Fersch 3D quoting application.

This script can be run in two modes:

1. **CLI mode**: Compute a quote for a local STL file by passing
   command‑line arguments. Example::

       python main.py --stl logan.stl --material "Tough 2000" \
           --type-piece "Prototype / Standard" --typology "Standard" --quantity 1

   The resulting breakdown is printed as JSON to stdout.

2. **Web server mode**: Start a minimal FastAPI application to serve a
   quoting form and process uploads. Use the `--serve` flag to launch
   the server. The server listens on the host/port specified in
   environment variables (`HOST` and `PORT`) or defaults to
   `0.0.0.0:8000`.

The web server does not rely on the `python-multipart` package. It
implements a simple parser for multipart/form-data requests based on
splitting the request body by the boundary defined in the
Content‑Type header. Only basic text fields and a single file upload
are supported.

Author: Fersch 3D quoting engine
"""

from __future__ import annotations

import json
import os
import sys
from argparse import ArgumentParser
from pathlib import Path
from typing import Any, Dict, Tuple

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from starlette.responses import RedirectResponse

from .quote_engine import QuoteEngine
from .stl_volume import compute_volume_ml, compute_volume_and_bbox


def parse_multipart(body: bytes, content_type: str) -> Dict[str, Any]:
    """Parse a multipart/form-data payload without python-multipart.

    The result is a dictionary mapping field names to either a string
    (for regular fields) or a tuple `(filename, content_bytes)` for
    uploaded files.

    Args:
        body: Raw request body.
        content_type: Value of the Content-Type header.

    Returns:
        Dictionary with parsed fields.
    """
    # Extract boundary from content-type header
    # Example header: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW
    boundary = None
    for part in content_type.split(";"):
        part = part.strip()
        if part.startswith("boundary="):
            boundary = part.split("=", 1)[1]
            break
    if not boundary:
        return {}
    boundary_bytes = ("--" + boundary).encode()
    # Split body by boundary markers
    segments = body.split(boundary_bytes)
    fields: Dict[str, Any] = {}
    for segment in segments:
        segment = segment.strip()
        # Skip empty or closing boundary
        if not segment or segment == b"--":
            continue
        # Each segment has headers and content separated by double CRLF
        try:
            header_part, content = segment.split(b"\r\n\r\n", 1)
        except ValueError:
            continue
        # Remove trailing CRLF from content
        content = content.rstrip(b"\r\n")
        # Parse headers
        headers = {}
        for header_line in header_part.split(b"\r\n"):
            if b":" in header_line:
                name, value = header_line.split(b":", 1)
                headers[name.strip().lower()] = value.strip().decode()
        disp = headers.get(b"content-disposition", headers.get("content-disposition"))
        if not disp:
            continue
        # Extract field name and optional filename
        name = None
        filename = None
        # content-disposition: form-data; name="field"; filename="file.stl"
        for item in disp.split(";"):
            item = item.strip()
            if item.startswith("name="):
                name = item.split("=", 1)[1].strip("\"")
            elif item.startswith("filename="):
                filename = item.split("=", 1)[1].strip("\"")
        if not name:
            continue
        if filename:
            fields[name] = (filename, content)
        else:
            fields[name] = content.decode(errors="ignore")
    return fields


def serve_app(engine: QuoteEngine) -> FastAPI:
    """Create a FastAPI app for uploading STL files and obtaining quotes."""
    app = FastAPI()

    @app.get("/")
    async def form() -> HTMLResponse:
        # Render a simple HTML form for uploading an STL and selecting options
        material_options = "".join(
            f'<option value="{name}">{name}</option>' for name in engine.materials.keys()
        )
        type_options = "".join(
            f'<option value="{name}">{name}</option>' for name in engine.type_pieces.keys()
        )
        typology_options = "".join(
            f'<option value="{name}">{name}</option>' for name in engine.typologies.keys()
        )
        html = f"""
        <html>
          <head>
            <title>Devis Fersch 3D</title>
            <style>
              body {{ font-family: Arial, sans-serif; background: #f5f5f5; padding: 2rem; }}
              .container {{ max-width: 600px; margin: auto; background: white; padding: 1rem 2rem; border-radius: 8px; box-shadow: 0 2px 6px rgba(0,0,0,0.1); }}
              h1 {{ text-align: center; }}
              label {{ display: block; margin-top: 1rem; }}
              input, select {{ width: 100%; padding: 0.5rem; margin-top: 0.25rem; }}
              button {{ margin-top: 1rem; padding: 0.75rem; width: 100%; background: #FAC900; border: none; border-radius: 4px; font-size: 1rem; cursor: pointer; }}
            </style>
          </head>
          <body>
            <div class="container">
              <h1>Demande de devis</h1>
              <form action="/quote" method="post" enctype="multipart/form-data">
                <label>Fichier STL</label>
                <input type="file" name="stlfile" accept=".stl,.obj" required />

                <label>Matière</label>
                <select name="material">{material_options}</select>

                <label>Type de pièce</label>
                <select name="type_piece">{type_options}</select>

                <label>Typologie</label>
                <select name="typology">{typology_options}</select>

                <label>Quantité</label>
                <input type="number" name="quantity" value="1" min="1" />

                <label>Mode de livraison</label>
                <select name="shipping">
                  <option value="retrait">Retrait gratuit</option>
                  <option value="livraison">Livraison (supplément)</option>
                </select>

                <button type="submit">Obtenir mon devis</button>
              </form>
            </div>
          </body>
        </html>
        """
        return HTMLResponse(content=html)

    @app.post("/quote")
    async def upload_quote(request: Request) -> HTMLResponse:
        # Read raw body
        body = await request.body()
        content_type = request.headers.get("content-type", "")
        fields = parse_multipart(body, content_type)
        # Extract fields
        file_tuple = fields.get("stlfile")
        if not file_tuple or not isinstance(file_tuple, tuple):
            return HTMLResponse(content="<p>Erreur: fichier manquant.</p>", status_code=400)
        filename, file_content = file_tuple
        material = fields.get("material") or next(iter(engine.materials.keys()))
        type_piece = fields.get("type_piece") or next(iter(engine.type_pieces.keys()))
        typology = fields.get("typology") or next(iter(engine.typologies.keys()))
        quantity_str = fields.get("quantity", "1")
        try:
            quantity = max(1, int(quantity_str))
        except ValueError:
            quantity = 1
        shipping = fields.get("shipping", "retrait")
        # Save uploaded file temporarily
        temp_path = Path("/tmp") / ("upload_" + filename)
        with open(temp_path, "wb") as f:
            f.write(file_content)
        # Compute volume and bounding box
        try:
            volume_ml, dims = compute_volume_and_bbox(temp_path)
        except Exception as exc:
            return HTMLResponse(content=f"<p>Erreur lors du calcul du volume: {exc}</p>", status_code=500)
        largest_dim = dims[0] if dims else None
        # Compute quote
        quote = engine.compute_quote(
            volume_ml=volume_ml,
            material_name=material,
            type_piece_name=type_piece,
            typology_name=typology,
            quantity=quantity,
            shipping_method=shipping,
            largest_dimension_mm=largest_dim,
        )
        # Build HTML response
        breakdown_rows = "".join(
            f"<tr><td>{key.replace('_', ' ').title()}</td><td>{value:.2f} €</td></tr>"
            for key, value in quote.items()
            if key in ['material_cost', 'machine_cost', 'post_cost', 'finish_cost', 'price_ht_plate', 'packaging_cost', 'bag_cost', 'shipping_cost', 'total_ht', 'vat', 'total_ttc']
        )
        # Volume with supports and print time display
        volume_total = quote.get('volume_with_supports_ml', volume_ml * quantity)
        print_time_min = quote.get('print_time_minutes')
        html = f"""
        <html><head><title>Votre devis</title><style>
        body {{ font-family: Arial, sans-serif; background: #f5f5f5; padding: 2rem; }}
        .container {{ max-width: 600px; margin: auto; background: white; padding: 1rem 2rem; border-radius: 8px; box-shadow: 0 2px 6px rgba(0,0,0,0.1); }}
        h1 {{ text-align: center; }}
        table {{ width: 100%; border-collapse: collapse; margin-top: 1rem; }}
        td {{ padding: 0.5rem; border-bottom: 1px solid #ddd; }}
        td:first-child {{ font-weight: bold; }}
        </style></head><body>
        <div class="container">
        <h1>Votre devis</h1>
        <p><strong>Volume pièce:</strong> {volume_ml*quantity:.2f} ml</p>
        <p><strong>Volume avec supports:</strong> {volume_total:.2f} ml</p>
        <p><strong>Temps d'impression estimé:</strong> {print_time_min:.1f} minutes</p>
        <table>
          {breakdown_rows}
        </table>
        <p><a href="/">&#8592; Faire un autre devis</a></p>
        </div></body></html>
        """
        return HTMLResponse(content=html)

    return app


def cli(engine: QuoteEngine, args: Any) -> None:
    """Run the quoting engine in CLI mode."""
    # Compute volume
    volume, dims = compute_volume_and_bbox(args.stl)
    largest_dim = dims[0] if dims else None
    quote = engine.compute_quote(
        volume_ml=volume,
        material_name=args.material,
        type_piece_name=args.type_piece,
        typology_name=args.typology,
        quantity=args.quantity,
        shipping_method=args.shipping,
        largest_dimension_mm=largest_dim,
    )
    print(json.dumps({'volume_ml': volume, 'largest_dimension_mm': largest_dim, **quote}, indent=2))


def main() -> None:
    parser = ArgumentParser(description="Fersch 3D quoting tool")
    parser.add_argument("--stl", type=str, help="Path to STL file for CLI mode")
    parser.add_argument("--material", type=str, default=None, help="Material name")
    parser.add_argument("--type-piece", type=str, default=None, help="Type de pièce")
    parser.add_argument("--typology", type=str, default=None, help="Typology name")
    parser.add_argument("--quantity", type=int, default=1, help="Quantity of pieces")
    parser.add_argument("--shipping", type=str, choices=["retrait", "livraison"], default="retrait", help="Shipping method")
    parser.add_argument("--serve", action="store_true", help="Start web server instead of CLI")
    args = parser.parse_args()
    # Determine excel path
    excel_path = os.getenv("EXCEL_FILE", "../Calcul prix 3D FERSCH.xlsx")
    engine = QuoteEngine(excel_path)
    if args.serve:
        app = serve_app(engine)
        import uvicorn  # type: ignore
        host = os.getenv("HOST", "0.0.0.0")
        port = int(os.getenv("PORT", "8000"))
        uvicorn.run(app, host=host, port=port)
    else:
        # CLI requires --stl
        if not args.stl:
            parser.error("--stl is required in CLI mode")
        # Set defaults if not provided
        args.material = args.material or next(iter(engine.materials.keys()))
        args.type_piece = args.type_piece or next(iter(engine.type_pieces.keys()))
        args.typology = args.typology or next(iter(engine.typologies.keys()))
        cli(engine, args)


if __name__ == "__main__":
    main()
