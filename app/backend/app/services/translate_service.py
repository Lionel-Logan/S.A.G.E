from app.services.gemini_service import GeminiService
# from app.services.libre_service import LibreService # <--- NEW

class TranslateService:
    def __init__(self):
        # self.ocr_engine = GeminiService() # The "Eye" (extracts text)
        # self.translator = LibreService()  # The "Linguist" (translates text)
        # We use Gemini for BOTH reading (OCR) and translating
        self.ai = GeminiService()

    async def translate_text(self, text: str, target_lang: str = "fr") -> str:
        
        # "fr" is French. You can make this dynamic based on user settings later.
        # --- DEBUG PRINT ---
        # print(f"\n[LOG] 🟢 Route: TEXT ONLY -> Sending '{text}' to LibreTranslate...")
        # # -------------------
        # return await self.translator.translate(text, target_lang)
        # Gemini is smart enough to handle the translation directly
        prompt = f"Translate the following text to {target_lang}. Output ONLY the translated text.\n\nText: {text}"
        return await self.ai.ask(prompt)

    async def translate_image(self, image_data: str, target_lang: str = "fr") -> str:
        # """
        # Hybrid Pipeline:
        # 1. Gemini extracts text (OCR).
        # 2. LibreTranslate translates that text.
        # """
        # # Step 1: OCR (Using Gemini to just "Read")
        # # --- DEBUG PRINT ---
        # print(f"\n[LOG] 🔵 Route: VISION -> Sending Image to Gemini for OCR...")
        # # -------------------
        # ocr_prompt = "Read the text in this image. Output ONLY the raw text you see. Do not translate it yet."
        # extracted_text = await self.ocr_engine.ask_with_image(ocr_prompt, image_data)
        
        # if not extracted_text or "error" in extracted_text.lower():
        #     return "I could not read any text in that image."

        # print(f"[DEBUG] Extracted Text: {extracted_text}")
        # print(f"[LOG] 👁️ Gemini Saw: '{extracted_text}'")
        # print(f"[LOG] 🟢 Handing over to LibreTranslate...")
        # # Step 2: Translation (Using LibreTranslate)
        # translated_text = await self.translator.translate(extracted_text, target_lang)
        
        # return f"Original: {extracted_text}\nTranslation: {translated_text}"

        """
        Scenario: User looks at a menu and wants it read in Spanish.
        """
        # One-shot prompt: Look + Read + Translate
        prompt = (
            f"Look at this image. Extract the text and translate it directly into {target_lang}. "
            f"Return the format: 'Original: [text] \n Translation: [text]'"
        )
        return await self.ai.ask_with_image(prompt, image_data)