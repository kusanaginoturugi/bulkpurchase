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
  return `<span class="item-label">${before}<strong class="variant">${escapeHtml(variant[0])}</strong>${after}</span>`;
}

function orderPdfHtml(input: {
  label: string;
  orderDate: string;
  arrivalDate: string;
  isAdditionalOrder?: boolean;
  fellowships: PdfFellowship[];
  rows: PdfRow[];
}, density = 1) {
  const date = new Date(`${input.arrivalDate}T00:00:00Z`);
  const weekday = ["日", "月", "火", "水", "木", "金", "土"][date.getUTCDay()];
  const arrivalLabel = `${date.getUTCMonth() + 1}月${date.getUTCDate()}日(${weekday})　弥勒大仏殿必着`;
  const fellowshipCount = input.fellowships.length;
  const denseTable = input.rows.length >= 12;
  const tableFontSize = denseTable ? fellowshipCount <= 5 ? 12 : 10.5 : fellowshipCount <= 2 ? 16 : fellowshipCount <= 5 ? 14 : 12;
  const headerFontSize = denseTable ? fellowshipCount <= 5 ? 15 : 13 : fellowshipCount <= 2 ? 18 : fellowshipCount <= 5 ? 16 : 13;
  const rowHeight = denseTable ? 7.4 : input.rows.length >= 11 ? 10.5 : input.rows.length >= 9 ? 11.5 : fellowshipCount <= 2 ? 15 : fellowshipCount <= 5 ? 13 : 12;
  const titleFontSize = denseTable ? 22 : 24;
  const metaFontSize = denseTable ? 13.5 : 15;
  const scale = Math.max(0.18, Math.min(1, density));
  const compactMargin = Math.max(4, 11 * scale);
  const headers = input.fellowships.map((fellowship) => `<th>${escapeHtml(fellowship.name)}</th>`).join("");
  const rows = input.rows.length
    ? input.rows.map((row) => { const added = Boolean(row.addedFellowshipIds?.length); return `<tr><td class="item${added ? " added" : ""}">${htmlItemName(`${row.name}${row.unit === "組" ? "(組)" : ""}`)}</td>${input.fellowships.map((fellowship) => `<td class="${row.addedFellowshipIds?.includes(fellowship.id) ? "added" : ""}">${row.quantities[fellowship.id] || ""}</td>`).join("")}<td class="total${added ? " added" : ""}">${row.total}</td></tr>`; }).join("")
    : `<tr><td class="empty" colspan="${input.fellowships.length + 2}">提出済みの注文はありません</td></tr>`;

  return `<!doctype html><html lang="ja"><head><meta charset="utf-8"><style>
    @page { size: A4 landscape; margin: ${compactMargin}mm 10mm; }
    @font-face { font-family:"OrderPdf"; src:url("data:font/ttf;base64,${pdfFontBase64}") format("truetype"); font-weight:400 700; }
    * { box-sizing: border-box; } html,body { margin:0; padding:0; color:#161616; background:#fff; }
    body { font-family:"OrderPdf",sans-serif; } .sheet { width:100%; }
    .title-line { position:relative; } h1 { margin:0; text-align:center; font-family:"OrderPdf",sans-serif; font-size:${titleFontSize * scale}pt; line-height:1.18; font-weight:700; letter-spacing:.04em; } .additional { position:absolute; left:0; top:0; color:#a71d1d; font-family:"OrderPdf",sans-serif; font-size:${32 * scale}pt; line-height:1; font-weight:700; }
    .meta { margin:${1.5 * scale}mm 0 ${2 * scale}mm; display:flex; justify-content:space-between; align-items:center; font-family:"OrderPdf",sans-serif; font-size:${metaFontSize * scale}pt; font-weight:700; }
    table { width:100%; border-collapse:collapse; table-layout:fixed; border:1.2pt solid #242424; font-size:${tableFontSize * scale}pt; }
    th,td { border:.55pt solid #333; vertical-align:middle; text-align:center; line-height:1.08; padding:${(denseTable ? 0.45 : 1.1) * scale}mm ${(denseTable ? 0.7 : 1.2) * scale}mm; }
    th { background:#f2f0ec; height:${(rowHeight + (denseTable ? 1.6 : 3)) * scale}mm; font-size:${headerFontSize * scale}pt; font-weight:700; } td { height:${rowHeight * scale}mm; } th:first-child,td.item { width:31%; }
    th:last-child,td.total { width:8%; } td.item { padding:${(denseTable ? 0.45 : 1.2) * scale}mm ${(denseTable ? 1.2 : 3) * scale}mm; font-size:${tableFontSize * scale}pt; white-space:nowrap; } .item-label { white-space:nowrap; } .item-label .variant { font-family:"OrderPdf",sans-serif; font-weight:700; } td.total { font-family:"OrderPdf",sans-serif; font-weight:400; } td.added { font-family:"OrderPdf",sans-serif; font-weight:700; }
    tr { break-inside:avoid; } .empty { height:${25 * scale}mm; color:#555; } .footer { margin-top:${2 * scale}mm; text-align:right; font-family:"OrderPdf",sans-serif; font-size:${8.5 * scale}pt; color:#555; }
  </style></head><body><main class="sheet"><div class="title-line"><h1>聖明王院　一括道具注文書</h1>${input.isAdditionalOrder ? '<strong class="additional">追加</strong>' : ""}</div><div class="meta"><span>注文日　${escapeHtml(monthDay(input.orderDate))}</span><span>${escapeHtml(arrivalLabel)}</span></div><table><thead><tr><th>道具名</th>${headers}<th>合計</th></tr></thead><tbody>${rows}</tbody></table><div class="footer">聖明王院 道具一括注文</div></main></body></html>`;
}

async function createStyledOrderPdf(browser: BrowserRun, input: Parameters<typeof orderPdfHtml>[0], density = 1) {
  const response = await browser.quickAction("pdf", {
    html: orderPdfHtml(input, density),
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
    for (const density of [1, 0.78, 0.62, 0.48, 0.36, 0.26, 0.18]) {
      try {
        const bytes = await createStyledOrderPdf(browser, input, density);
        if ((await PDFDocument.load(bytes)).getPageCount() === 1) return bytes;
      } catch (error) {
        console.warn("ブラウザ描画PDFを予備の帳票へ切り替えました。", error);
        break;
      }
    }
  }
  const document = await PDFDocument.create();
  document.registerFontkit(fontkit);
  const font = await document.embedFont(fontBytes(), { subset: true });
  const page = document.addPage([pageWidth, pageHeight]);
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

  const rowHeight = (y - 28) / Math.max(input.rows.length + 1, 1);
  const drawRow = (cells: string[], headerRow = false) => {
    const height = rowHeight;
    const maxLines = Math.max(...cells.map((cell) => cell.split("\n").length));
    const size = Math.max(4, Math.min(headerRow ? 11 : 12, (height - 9) / Math.max(maxLines, 1) - 1));
    let x = margin;
    cells.forEach((cell, index) => {
      const cellWidth = widths[index];
      page.drawRectangle({ x, y: y - height, width: cellWidth, height, borderWidth: 0.8, borderColor: rgb(0, 0, 0) });
      const lines = cell.split("\n");
      lines.forEach((line, lineIndex) => {
        const lineBlockHeight = lines.length * (size + 1);
        const rowTop = y - (height - lineBlockHeight) / 2 - lineIndex * (size + 1);
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
