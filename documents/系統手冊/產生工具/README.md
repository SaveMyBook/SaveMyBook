# 系統手冊產生工具

以 `manual_v3_backup.docx` 為底稿，依序套用各 `update_*.py` 產生系統手冊完善版；圖檔原始碼在 `activity/`、`cabdiag/`、`aidiag/`、`review/`，其餘圖取自專案 `Diagrams/*/v3/`。

## 準備（第一次）

```bash
python3 -m venv .venv
.venv/bin/pip install python-docx pillow pymupdf
curl -L -o plantuml.jar https://repo1.maven.org/maven2/net/sourceforge/plantuml/plantuml/1.2025.4/plantuml-1.2025.4.jar
```

另需 Java 與 rsvg-convert（`brew install librsvg`）。

## 產生手冊

```bash
.venv/bin/python update_manual.py 輸出.docx
.venv/bin/python selfcheck.py 輸出.docx
```

自動檢查須顯示 `ALL OK`。產生後於 Word 開啟，更新目錄與圖表目錄（全選按 F9），存檔後再匯出 PDF。

圖目錄與表目錄為 `TOC \c \f` 功能變數：前幾章之說明以可見 SEQ 欄位收錄，其餘說明另有 TC 欄位（`update_lists.py`）；只用隱藏 SEQ 欄位時 Word 更新後只會列出前 4 章。

書櫃交通資訊（2026-10-02）之內文、UC-35／UC-36 與循序圖 6-1-32 由 `transit_part4.py` 加入，分三段在 `update_manual.py` 中呼叫。

## 修改圖

- 改 `.puml` 後重新產圖：循序圖用 `render_seq.py`，設計類別圖與訂單狀態機用 `render_class.py`，其餘用 `java -jar plantuml.jar -tpng 檔案.puml`。
- 檢查重疊：`.venv/bin/python overlap_check.py`（須為 0）；檢查字級：`.venv/bin/python a4check.py 圖.png`（ER 圖加 `--font 12` 且放在第一個參數）。
- 同步到專案 `Diagrams`：`.venv/bin/python sync_diagrams.py`。

## 用詞修正

名詞與描述修正集中在 `audit/build_corrections.py`（產生 `audit/corrections.json`），由 `update_terms.py` 套用；改完先執行 `.venv/bin/python audit/build_corrections.py` 再產生手冊。

## 排版

- 第 1～7 章與前置頁沿用 `reference/複評版_1001.docx` 之手動排版（分頁、段落與表格格式、圖尺寸、腳註），由 `update_1001.py` 依文字比對套用；排好更多章節時以新檔覆蓋此參考檔即可。
- 第 8 章起依同一方式接續：各節自新頁開始、一圖一頁且說明與圖名同頁；接近一頁高之表格自新頁開始，較長者任其跨頁並重複表頭。表格高度與段落行數之估算見 `layout_measure.py`（依 Word 實測）。
- 檢查實際分頁：`.venv/bin/python render_word.py 輸出.docx` 以本機 Word 轉成 `_render/manual.pdf`。本機須安裝標楷體（KAIU.TTF），否則 Word 改用行高較大之字型，分頁與 Windows 不同。
