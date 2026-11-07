#!/usr/bin/env bats

@test "headless core omits Inkscape" {
  [[ "$ENV_NAME" == "datascience-core" ]] || skip "Notebook image"
  ! command -v inkscape
}

@test "notebook exports text, PNG and SVG figures to PDF" {
  [[ "$ENV_NAME" != "datascience-core" ]] || skip "No notebook feature"
  python - <<'PY'
import nbformat
from nbconvert import PDFExporter

# Saved display output exercises export without executing a user's notebook.
png = "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFUlEQVR4nGP8//8/AzbAhFV00EoAAFbUAw037MyjAAAAAElFTkSuQmCC"
svg = '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="60"><rect x="5" y="5" width="100" height="40" fill="steelblue"/></svg>'
for name, data in (
    ("text", None),
    ("PNG", {"image/png": png}),
    ("SVG", {"image/svg+xml": svg}),
):
    cells = [nbformat.v4.new_markdown_cell("# Synthetic PDF export")]
    if data:
        cells.append(nbformat.v4.new_code_cell(
            "# synthetic figure",
            outputs=[nbformat.v4.new_output("display_data", data=data)],
        ))
    notebook = nbformat.v4.new_notebook(
        cells=cells, metadata={"language_info": {"name": "python"}},
    )
    pdf, _ = PDFExporter().from_notebook_node(notebook)
    assert pdf.startswith(b"%PDF"), f"{name}: no PDF produced"
    print(f"{name}: exported {len(pdf)} bytes")
PY
}
