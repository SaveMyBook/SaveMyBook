"""旁白稿與字幕用文字：旁白內容與時間在 ../src/timeline.json，實際起訖時間在 tts/meta.json。"""
import json
LINES = [(m["start"], m["end"], m["text"]) for m in json.load(open("tts/meta.json", encoding="utf-8"))]

def subtitle_text(s):
    """字幕顯示用：TTS 讀音寫法換回正式名稱。"""
    return s.replace("救舊我的書", "救「舊」我的書")
