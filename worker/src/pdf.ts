import fontkit from "@pdf-lib/fontkit";
import { PDFDocument, rgb } from "pdf-lib";

import { pdfFontBase64 } from "./pdf-font";

export interface PdfRow {
  name: string;
  unit: string;
  quantities: Record<number, number>;
  total: number;
}

export interface PdfFellowship {
  id: number;
  name: string;
}

const pageWidth = 841.89;
const pageHeight = 595.28;

function fontBytes() {
  const raw = atob(pdfFontBase64);
  return Uint8Array.from(raw, (character) => character.charCodeAt(0));
}

function wrapName(name: string) {
  return name
    .replace(/\s*\/\s*/g, "\n")
    .replace(/\s*([（(])/g, "\n$1")
    .replace(/・\s*/g, "・\n");
}

export async function createOrderPdf(input: {
  label: string;
  orderDate: string;
  arrivalDate: string;
  fellowships: PdfFellowship[];
  rows: PdfRow[];
}) {
  const document = await PDFDocument.create();
  document.registerFontkit(fontkit);
  const font = await document.embedFont(fontBytes(), { subset: true });
  let page = document.addPage([pageWidth, pageHeight]);
  const { width } = page.getSize();
  const margin = 24;
  const nameWidth = 150;
  const totalWidth = 52;
  const quantityWidth = (width - margin * 2 - nameWidth - totalWidth) / Math.max(input.fellowships.length, 1);
  const widths = [nameWidth, ...input.fellowships.map(() => quantityWidth), totalWidth];
  let y = pageHeight - 30;

  const text = (value: string, x: number, top: number, size: number, align: "left" | "center" | "right" = "left", boxWidth = 0) => {
    const valueWidth = font.widthOfTextAtSize(value, size);
    const left = align === "center" ? x + (boxWidth - valueWidth) / 2 : align === "right" ? x + boxWidth - valueWidth : x;
    page.drawText(value, { x: left, y: top - size, size, font, color: rgb(0.08, 0.1, 0.16) });
  };

  // 日付だけをUTCとして扱い、日本時間の曜日が前日にずれないようにする。
  const date = new Date(`${input.arrivalDate}T00:00:00Z`);
  const weekday = ["日", "月", "火", "水", "木", "金", "土"][date.getUTCDay()];
  const header = `※${date.getUTCMonth() + 1}月${date.getUTCDate()}日(${weekday})までに弥勒大仏殿着でお願いします。`;
  text(header, margin, y, 15, "center", width - margin * 2);
  y -= 28;
  text("聖明王院 一括道具注文書", margin, y, 19, "center", width - margin * 2);
  y -= 30;
  text(`【注文日】 ${input.orderDate}`, margin, y, 12);
  y -= 16;

  const drawRow = (cells: string[], headerRow = false) => {
    const height = 37;
    if (y - height < 28) {
      page = document.addPage([pageWidth, pageHeight]);
      y = pageHeight - 30;
    }
    let x = margin;
    cells.forEach((cell, index) => {
      const cellWidth = widths[index];
      page.drawRectangle({ x, y: y - height, width: cellWidth, height, borderWidth: 0.8, borderColor: rgb(0, 0, 0) });
      const lines = cell.split("\n");
      const size = headerRow ? 11 : 12;
      lines.forEach((line, lineIndex) => {
        const rowTop = y - 7 - lineIndex * (size + 1);
        const numeric = !headerRow && index > 0;
        const numericBox = Math.max(28, cellWidth * 0.52);
        const textX = numeric ? x + (cellWidth - numericBox) / 2 : x + 4;
        text(line, textX, rowTop, size, numeric ? "right" : "center", numeric ? numericBox : cellWidth - 8);
      });
      x += cellWidth;
    });
    y -= height;
  };

  drawRow(["", ...input.fellowships.map((fellowship) => fellowship.name), "合計"], true);
  input.rows.forEach((row) => {
    drawRow([
      wrapName(`${row.name}${row.unit ? ` (${row.unit})` : ""}`),
      ...input.fellowships.map((fellowship) => String(row.quantities[fellowship.id] || "")),
      String(row.total)
    ]);
  });

  return document.save();
}
