import fs from "node:fs/promises";
import { Workbook, SpreadsheetFile } from "@oai/artifact-tool";

const inputPng = "R:/AppTaxiLaquiaca/tmp/pdfs/checklist/checklist_300dpi.png";
const outputDir = "R:/AppTaxiLaquiaca/outputs/checklist_automovil";

const workbook = Workbook.create();
const sheet = workbook.worksheets.add("CHECK LIST AUTOMOVIL");
sheet.showGridLines = false;

// A4 portrait at 96 dpi. The source is rendered at 300 dpi for sharp printing.
const pageWidthPx = 794;
const pageHeightPx = 1123;
const png = await fs.readFile(inputPng);
const dataUrl = `data:image/png;base64,${png.toString("base64")}`;

sheet.images.add({
  dataUrl,
  anchor: {
    from: { row: 0, col: 0 },
    extent: { widthPx: pageWidthPx, heightPx: pageHeightPx },
  },
});

// Reserve a clean A4-sized canvas behind the embedded form.
sheet.getRange("A1:N56").format.fill = "#FFFFFF";
sheet.getRange("A1:N56").format.rowHeightPx = 20;
sheet.getRange("A1:N1").format.columnWidthPx = 57;

workbook.recalculate();
await fs.mkdir(outputDir, { recursive: true });

const preview = await workbook.render({
  sheetName: "CHECK LIST AUTOMOVIL",
  range: "A1:N56",
  scale: 1,
  format: "png",
});
await fs.writeFile(`${outputDir}/preview.png`, new Uint8Array(await preview.arrayBuffer()));

const inspection = await workbook.inspect({
  kind: "sheet,drawing",
  sheetId: "CHECK LIST AUTOMOVIL",
  maxChars: 4000,
});
await fs.writeFile(`${outputDir}/inspection.ndjson`, inspection.ndjson ?? "", "utf8");

const xlsx = await SpreadsheetFile.exportXlsx(workbook);
await xlsx.save(`${outputDir}/CHECK LIST AUTOMOVIL.xlsx`);
