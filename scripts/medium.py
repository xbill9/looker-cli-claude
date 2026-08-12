#!/usr/bin/env python3
"""Derive a Medium-ready variant of a dev.to article.

Medium renders no Markdown tables and has no use for dev.to frontmatter, so
this strips the frontmatter, promotes its title to an H1, and rewrites every
table as bold-headed bullet lists. The result is written alongside the source
as <name>-medium.md, then rendered to <name>-medium.html for Medium's importer.

    python3 scripts/medium.py docs/some-article.md

Tables inside fenced code blocks are terminal output, not comparisons, and are
left untouched.
"""
import pathlib
import re
import shutil
import subprocess
import sys


def split_row(line):
    """Split a Markdown table row into cells, honouring escaped pipes."""
    body = line.strip().strip("|")
    return [c.replace("\x00", "|").strip()
            for c in body.replace(r"\|", "\x00").split("|")]


def table_to_lists(rows):
    """Rewrite a Markdown table as bold-headed bullet lists.

    A comparison table with an empty top-left cell groups by column: each
    column header becomes a heading and each row label becomes a bullet.
    Any other table groups by row instead.
    """
    header, body = split_row(rows[0]), [split_row(r) for r in rows[2:]]
    blocks = []

    if not header[0]:
        for col in range(1, len(header)):
            bullets = [f"- {r[0]}: {r[col]}" for r in body
                       if len(r) > col and r[col]]
            blocks.append("\n".join([f"**{header[col]}**", *bullets]))
    else:
        for r in body:
            bullets = [f"- {header[col]}: {r[col]}" for col in range(1, len(r))
                       if r[col]]
            blocks.append("\n".join([f"**{r[0]}**", *bullets]))

    return "\n\n".join(blocks)


def convert(text):
    """Strip frontmatter, promote the title, and delist every table."""
    title = None
    if text.startswith("---"):
        _, front, text = text.split("---", 2)
        m = re.search(r"^title:\s*(.+)$", front, re.M)
        title = m.group(1).strip() if m else None
        text = text.lstrip("\n")

    out, pending, in_fence, count = [], [], False, 0
    for line in text.splitlines():
        if line.startswith("```"):
            in_fence = not in_fence
        if not in_fence and line.startswith("|"):
            pending.append(line)
            continue
        if pending:
            out.append(table_to_lists(pending))
            count += 1
            pending = []
        out.append(line)
    if pending:
        out.append(table_to_lists(pending))
        count += 1

    md = "\n".join(out)
    if title and not md.lstrip().startswith("# "):
        md = f"# {title}\n\n{md.lstrip()}"
    return md, title, count


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: medium.py <article.md>")

    src = pathlib.Path(sys.argv[1])
    if not src.is_file():
        sys.exit(f"error: no such file: {src}")
    if src.stem.endswith("-medium"):
        sys.exit(f"error: {src.name} is already a Medium variant")
    if not shutil.which("pandoc"):
        sys.exit("error: pandoc is required — install it and re-run")

    md, title, count = convert(src.read_text(encoding="utf-8"))

    # Verify no table survived, ignoring fenced blocks — box-drawn terminal
    # output legitimately starts lines with a pipe.
    unfenced = re.sub(r"^```.*?^```", "", md, flags=re.M | re.S)
    if re.search(r"^\|", unfenced, re.M):
        sys.exit("error: a table survived conversion — check the source")

    out_md = src.with_name(f"{src.stem}-medium.md")
    out_html = out_md.with_suffix(".html")
    out_md.write_text(md, encoding="utf-8")

    cmd = ["pandoc", "-s", "-f", "markdown", "-t", "html5",
           "-o", str(out_html), str(out_md)]
    if title:
        cmd[2:2] = ["--metadata", f"title={title}"]
    subprocess.run(cmd, check=True)

    print(f"{out_md}   ({count} table(s) converted to lists)")
    print(f"{out_html}   ({out_html.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
