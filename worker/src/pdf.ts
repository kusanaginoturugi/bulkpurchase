import fontkit from "@pdf-lib/fontkit";
import { PDFDocument, rgb } from "pdf-lib";

import { pdfFontBase64 } from "./pdf-font";

export interface PdfRow {
  name: string;
  unit: string;
  quantities: Record<number, number>;
  total: number;
  addedFellowshipIds?: number[];
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
    .replace(/\s*([（(])(?!組[）)])/g, "\n$1")
    .replace(/・\s*/g, "・\n");
}

function escapeHtml(value: string) {
  return value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#039;");
}

function monthDay(value: string) {
  const date = new Date(`${value.slice(0, 10)}T00:00:00Z`);
  return Number.isNaN(date.getTime()) ? value : `${date.getUTCMonth() + 1}月${date.getUTCDate()}日`;
}

function htmlItemName(name: string) {
  const variant = name.match(/「([^」]+)」/);
  const lineBreaks = (value: string) => escapeHtml(value).replace(/\s*\/\s*/g, "<br>").replace(/\s*([（(])(?!組[）)])/g, "<br>$1").replace(/・\s*/g, "・<br>");
  if (!variant) return lineBreaks(name);
  const variantStart = variant.index || 0;
  const before = lineBreaks(name.slice(0, variantStart));
  const after = lineBreaks(name.slice(variantStart + variant[0].length));
  return `<table class="item-label"><tr><td>${before}</td><td class="variant">${escapeHtml(variant[0])}</td><td>${after}</td></tr></table>`;
}

function orderPdfHtml(input: {
  label: string;
  orderDate: string;
  arrivalDate: string;
  isAdditionalOrder?: boolean;
  fellowships: PdfFellowship[];
  rows: PdfRow[];
}) {
  const date = new Date(`${input.arrivalDate}T00:00:00Z`);
  const weekday = ["日", "月", "火", "水", "木", "金", "土"][date.getUTCDay()];
  const arrivalLabel = `${date.getUTCMonth() + 1}月${date.getUTCDate()}日(${weekday})　弥勒大仏殿必着`;
  const fellowshipCount = input.fellowships.length;
  const tableFontSize = fellowshipCount <= 2 ? 16 : fellowshipCount <= 5 ? 14 : 12;
  const headerFontSize = fellowshipCount <= 2 ? 18 : fellowshipCount <= 5 ? 16 : 13;
  const rowHeight = input.rows.length >= 11 ? 10.5 : input.rows.length >= 9 ? 11.5 : fellowshipCount <= 2 ? 15 : fellowshipCount <= 5 ? 13 : 12;
  const headers = input.fellowships.map((fellowship) => `<th>${escapeHtml(fellowship.name)}</th>`).join("");
  const rows = input.rows.length
    ? input.rows.map((row) => { const added = Boolean(row.addedFellowshipIds?.length); return `<tr><td class="item${added ? " added" : ""}">${htmlItemName(`${row.name}${row.unit === "組" ? "(組)" : ""}`)}</td>${input.fellowships.map((fellowship) => `<td class="${row.addedFellowshipIds?.includes(fellowship.id) ? "added" : ""}">${row.quantities[fellowship.id] || ""}</td>`).join("")}<td class="total${added ? " added" : ""}">${row.total}</td></tr>`; }).join("")
    : `<tr><td class="empty" colspan="${input.fellowships.length + 2}">提出済みの注文はありません</td></tr>`;

  return `<!doctype html><html lang="ja"><head><meta charset="utf-8"><link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link href="https://fonts.googleapis.com/css2?family=Noto+Sans+JP:wght@400;500;700&family=Noto+Serif+JP:wght@400;500;700&display=block" rel="stylesheet"><style>
    @page { size: A4 landscape; margin: 11mm 10mm; }
    * { box-sizing: border-box; } html,body { margin:0; padding:0; color:#161616; background:#fff; }
    body { font-family:"Noto Serif JP","Yu Mincho",serif; } .sheet { width:100%; }
    .title-line { position:relative; } h1 { margin:0; text-align:center; font-family:"Noto Sans JP",sans-serif; font-size:24pt; line-height:1.3; font-weight:700; letter-spacing:.04em; } .additional { position:absolute; left:0; top:0; color:#a71d1d; font-family:"Noto Sans JP",sans-serif; font-size:32pt; line-height:1; font-weight:700; }
    .meta { margin:2mm 0 3mm; display:flex; justify-content:space-between; align-items:center; font-family:"Noto Sans JP",sans-serif; font-size:15pt; font-weight:700; }
    table { width:100%; border-collapse:collapse; table-layout:fixed; border:1.2pt solid #242424; font-size:${tableFontSize}pt; }
    th,td { border:.55pt solid #333; vertical-align:middle; text-align:center; line-height:1.2; padding:1.1mm 1.2mm; }
    th { background:#f2f0ec; height:${rowHeight + 3}mm; font-size:${headerFontSize}pt; font-weight:700; } td { height:${rowHeight}mm; } th:first-child,td.item { width:31%; }
    th:last-child,td.total { width:8%; } td.item { padding:1.2mm 3mm; font-size:${tableFontSize}pt; white-space:nowrap; } table.item-label { display:inline-table; width:auto; border:0; font:inherit; } table.item-label td { width:auto; height:auto; border:0; padding:0; font:inherit; white-space:nowrap; } table.item-label td.variant { font-family:"Noto Sans JP",sans-serif; font-weight:700; } td.total { font-family:"Noto Sans JP",sans-serif; font-weight:400; } td.added { font-family:"Noto Sans JP",sans-serif; font-weight:700; }
    tr { break-inside:avoid; } .empty { height:25mm; color:#555; } .footer { margin-top:3mm; text-align:right; font-family:"Noto Sans JP",sans-serif; font-size:8.5pt; color:#555; }
  </style></head><body><main class="sheet"><div class="title-line"><h1>聖明王院　一括道具注文書</h1>${input.isAdditionalOrder ? '<strong class="additional">追加</strong>' : ""}</div><div class="meta"><span>注文日　${escapeHtml(monthDay(input.orderDate))}</span><span>${escapeHtml(arrivalLabel)}</span></div><table><thead><tr><th>道具名</th>${headers}<th>合計</th></tr></thead><tbody>${rows}</tbody></table><div class="footer">聖明王院 道具一括注文</div></main></body></html>`;
}

async function createStyledOrderPdf(browser: BrowserRun, input: Parameters<typeof orderPdfHtml>[0]) {
  const response = await browser.quickAction("pdf", {
    html: orderPdfHtml(input),
    gotoOptions: { waitUntil: "networkidle0", timeout: 45_000 },
    pdfOptions: { format: "a4", landscape: true, printBackground: true, preferCSSPageSize: true, margin: { top: "0", right: "0", bottom: "0", left: "0" } }
  });
  if (!response.ok) throw new Error(`帳票の描画に失敗しました（HTTP ${response.status}）`);
  return new Uint8Array(await response.arrayBuffer());
}

export async function createOrderPdf(input: {
  label: string;
  orderDate: string;
  arrivalDate: string;
  isAdditionalOrder?: boolean;
  fellowships: PdfFellowship[];
  rows: PdfRow[];
}, browser?: BrowserRun) {
  if (browser) {
    try {
      return await createStyledOrderPdf(browser, input);
    } catch (error) {
      console.warn("ブラウザ描画PDFを予備の帳票へ切り替えました。", error);
    }
  }
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
  const arrivalLabel = `${date.getUTCMonth() + 1}月${date.getUTCDate()}日(${weekday})　弥勒大仏殿必着`;
  text("聖明王院　一括道具注文書", margin, y, 22, "center", width - margin * 2);
  if (input.isAdditionalOrder) text("追加", margin, y + 2, 30);
  y -= 32;
  text(`注文日　${monthDay(input.orderDate)}`, margin, y, 15, "left");
  text(arrivalLabel, margin, y, 15, "right", width - margin * 2);
  y -= 29;

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
      wrapName(`${row.name}${row.unit === "組" ? "(組)" : ""}`),
      ...input.fellowships.map((fellowship) => String(row.quantities[fellowship.id] || "")),
      String(row.total)
    ]);
  });

  return document.save();
}
