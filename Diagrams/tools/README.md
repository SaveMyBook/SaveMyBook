# 圖檔產生與重疊檢查工具

循序圖與設計類別圖若直接用 PlantUML 產生 PNG，會出現文字壓線、標記被連線穿過的問題，請改用本資料夾的程式產圖。其他圖照常用 PlantUML 產生即可。

## 環境需求

- Java
- PlantUML 1.2025.4：把 `plantuml.jar` 放在本資料夾，或以環境變數 `PLANTUML_JAR` 指定路徑。版本不同時，版面可能會改變。
- rsvg-convert：`brew install librsvg`
- Python 3 與 Pillow：`pip install pillow`
- 字型 PingFang TC（macOS 內建）

## 產圖

| 圖 | 指令 |
|---|---|
| 循序圖（`Sequence Diagrams/v3/*.puml`） | `python3 render_seq.py 檔案.puml` |
| 設計類別圖（`Class diagram/v3/design_class.puml`） | `python3 render_class.py 檔案.puml` |
| 其他圖 | `java -jar plantuml.jar -tpng 檔案.puml` |

PNG 會輸出在 `.puml` 旁邊，並內嵌原始碼，供手冊自動檢查比對。

- `render_seq.py`：把訊息文字移到最上層，並墊上白底，避免生命線穿過文字。
- `render_class.py`：Graphviz 會把多重性固定放在線端的一側，斜線常穿過自己的標記；本程式把這類文字就近移到不碰線、不碰框、不與其他文字相疊的位置。只處理原始碼含 `render_class.py` 字樣的圖。

## 重疊檢查

```bash
python3 overlap_check.py
```

不加參數時，檢查 `Diagrams/*/v3/` 下所有 `.puml`；也可以指定個別檔案。檢查項目如下：

- 文字互相重疊
- 文字壓到框線
- 連線穿過文字
- 連線重疊或距離過近
- 箭頭相連

修改圖後，請確認輸出結果為 `diagrams with issues: 0`。
