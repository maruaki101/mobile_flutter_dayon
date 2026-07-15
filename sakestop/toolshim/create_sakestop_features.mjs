import fs from "node:fs/promises";
import { Presentation, PresentationFile } from "file:///C:/Users/mingw/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs";

const outDir = "C:/Users/mingw/mobile_flutter_dayon/sakestop/outputs";
await fs.mkdir(outDir, { recursive: true });

const deck = Presentation.create({ slideSize: { width: 1280, height: 720 } });
const slide = deck.slides.add();
slide.background.fill = "#F7F3DF";

function addText(name, text, left, top, width, height, size, bold = false, color = "#173D38", align = "left") {
  const box = slide.shapes.add({
    geometry: "textbox", name,
    position: { left, top, width, height }, fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  box.text = text;
  box.text.style = { fontFamily: "Yu Gothic", fontSize: size, bold, color, alignment: align, verticalAlignment: "middle" };
  return box;
}

addText("title", "実装した主な3つの機能", 82, 62, 1116, 70, 42, true, "#173D38");
addText("subtitle", "注文から記録・通知までを一連の流れとして実装", 84, 134, 1110, 38, 20, false, "#5E6F67");

const cards = [
  { n: "1", title: "注文機能", body: "商品追加・数量変更・削除・注文確定", note: "注文操作をそのまま飲酒記録につなげる" },
  { n: "2", title: "データベース保存", body: "注文確定時にFirebaseへリアルタイム保存", note: "履歴を即時に保存・反映して確認できる" },
  { n: "3", title: "ペース記録通知", body: "飲酒ペースを記録し、飲み過ぎを通知", note: "経過時間と注文履歴からペースを見える化" },
];

for (let i = 0; i < cards.length; i++) {
  const x = 82 + i * 382;
  const panel = slide.shapes.add({
    geometry: "roundRect", name: `feature-${i + 1}`,
    position: { left: x, top: 214, width: 354, height: 390 },
    fill: "#FFFDF4", line: { style: "solid", fill: "#C9D7CF", width: 2 },
    borderRadius: "rounded-xl",
  });
  slide.shapes.add({
    geometry: "rect", name: `feature-band-${i + 1}`,
    position: { left: x, top: 214, width: 354, height: 86 },
    fill: "#DCECE4", line: { style: "solid", fill: "#DCECE4", width: 0 },
  });
  addText(`number-${i + 1}`, cards[i].n, x, 225, 354, 54, 30, true, "#173D38", "center");
  addText(`feature-title-${i + 1}`, cards[i].title, x + 28, 330, 298, 50, 27, true, "#173D38");
  addText(`feature-body-${i + 1}`, cards[i].body, x + 28, 402, 298, 86, 19, false, "#334B45");
  addText(`feature-note-${i + 1}`, cards[i].note, x + 28, 514, 298, 62, 16, false, "#6B7B75");
}

addText("footer", "SakeStop", 82, 650, 200, 24, 14, true, "#83918B");

const png = await deck.export({ slide, format: "png", scale: 1 });
await fs.writeFile(`${outDir}/SakeStop_3features_preview.png`, new Uint8Array(await png.arrayBuffer()));
const layout = await slide.export({ format: "layout" });
await fs.writeFile(`${outDir}/SakeStop_3features_layout.json`, await layout.text());
const pptx = await PresentationFile.exportPptx(deck);
await pptx.save(`${outDir}/SakeStop_3features.pptx`);
