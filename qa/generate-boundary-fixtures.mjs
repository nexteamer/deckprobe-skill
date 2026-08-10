import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const outputDir = join(here, "fixtures", "generated");
mkdirSync(outputDir, { recursive: true });

function buildPdf(payloadLength) {
  const chunks = [];
  const offsets = [0];
  let length = 0;

  function add(value) {
    const chunk = Buffer.isBuffer(value) ? value : Buffer.from(value, "binary");
    chunks.push(chunk);
    length += chunk.length;
  }

  function addObject(id, body) {
    offsets[id] = length;
    add(`${id} 0 obj\n`);
    add(body);
    add("\nendobj\n");
  }

  add("%PDF-1.7\n%\xE2\xE3\xCF\xD3\n");
  addObject(1, "<< /Type /Catalog /Pages 2 0 R >>");
  addObject(2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>");
  addObject(3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>");

  offsets[4] = length;
  add("4 0 obj\n");
  add(`<< /Length ${payloadLength} >>\nstream\n`);
  add(Buffer.alloc(payloadLength, 0x41));
  add("\nendstream\nendobj\n");

  const xrefOffset = length;
  add("xref\n0 5\n0000000000 65535 f \n");
  for (let id = 1; id <= 4; id += 1) {
    add(`${String(offsets[id]).padStart(10, "0")} 00000 n \n`);
  }
  add(`trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF\n`);
  return Buffer.concat(chunks);
}

function writeExactPdf(filename, targetBytes) {
  let payloadLength = Math.max(0, targetBytes - 512);
  let pdf = buildPdf(payloadLength);
  for (let attempt = 0; attempt < 8 && pdf.length !== targetBytes; attempt += 1) {
    payloadLength += targetBytes - pdf.length;
    if (payloadLength < 0) throw new Error(`target too small: ${targetBytes}`);
    pdf = buildPdf(payloadLength);
  }
  if (pdf.length !== targetBytes) {
    throw new Error(`could not reach ${targetBytes}; got ${pdf.length}`);
  }
  const destination = join(outputDir, filename);
  writeFileSync(destination, pdf);
  console.log(`${filename}\t${pdf.length}`);
}

const mib = 1024 * 1024;
writeExactPdf("pdf-budget-near-limit-minus-4k.pdf", 16 * mib - 4096);
writeExactPdf("pdf-budget-safe-16mib-minus-8.pdf", 16 * mib - 8);
writeExactPdf("pdf-budget-under-16mib.pdf", 16 * mib - 1);
writeExactPdf("pdf-budget-over-16mib.pdf", 16 * mib + 1);
writeExactPdf("pdf-large-32mib.pdf", 32 * mib);
