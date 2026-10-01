"""Извлекает текст из .docx (только stdlib). Таблицы — строками с разделителем ' | '.

Использование: python tools/extract_docx.py <путь-к-файлу.docx>
"""
import html
import re
import sys
import zipfile


def extract(path: str) -> str:
    xml = zipfile.ZipFile(path).read("word/document.xml").decode("utf-8")
    xml = re.sub(r"<w:tab/>", "\t", xml)
    xml = re.sub(r"<w:br[^>]*/>", "\n", xml)
    # абзацы внутри ячейки таблицы склеиваем через пробел
    xml = re.sub(r"<w:tc>.*?</w:tc>|<w:tc .*?</w:tc>",
                 lambda m: m.group(0).replace("</w:p>", " "), xml, flags=re.S)
    xml = re.sub(r"</w:tc>", " | ", xml)          # ячейки таблиц
    xml = re.sub(r"</w:tr>", "\n", xml)           # строки таблиц
    xml = re.sub(r"</w:p>", "\n", xml)            # абзацы
    text = html.unescape(re.sub(r"<[^>]+>", "", xml))
    text = re.sub(r"[ \t]*\|[ \t]*\n", "\n", text)  # хвостовой разделитель строки таблицы
    return re.sub(r"\n{3,}", "\n\n", text).strip()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Использование: python tools/extract_docx.py <файл.docx>")
    sys.stdout.reconfigure(encoding="utf-8")
    print(extract(sys.argv[1]))
