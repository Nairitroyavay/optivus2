const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const admin = require("firebase-admin");

admin.initializeApp();

// Define the secret parameter for the Gemini API key
const geminiApiKey = defineSecret("GEMINI_API_KEY");

exports.aiGenerate = onCall(
  { secrets: [geminiApiKey] },
  async (request) => {
    // Only allow authenticated users
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "The function must be called while authenticated."
      );
    }

    const { systemPrompt, userMessage, history } = request.data;

    if (!systemPrompt || !userMessage) {
      throw new HttpsError(
        "invalid-argument",
        "The function must be called with 'systemPrompt' and 'userMessage' arguments."
      );
    }

    try {
      // Access the secret API key
      const apiKey = geminiApiKey.value();
      if (!apiKey) {
        throw new HttpsError(
          "internal",
          "Gemini API key is not configured."
        );
      }

      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: "gemini-1.5-flash",
        systemInstruction: systemPrompt,
      });

      let responseText = "";

      if (history && Array.isArray(history)) {
        // Multi-turn chat
        const chat = model.startChat({
          history: history,
        });
        const result = await chat.sendMessage(userMessage);
        responseText = result.response.text();
      } else {
        // Single-shot text generation
        const result = await model.generateContent(userMessage);
        responseText = result.response.text();
      }

      return { text: responseText };
    } catch (error) {
      console.error("Error generating AI content:", error);
      throw new HttpsError("internal", "Failed to generate AI content.");
    }
  }
);
