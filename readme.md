https://somkiad.csbootstrap.com/Webhook


## index
// index.js
require('dotenv').config();
const express = require('express');
const line = require('@line/bot-sdk');
const { createClient } = require("@supabase/supabase-js");
const { GoogleGenerativeAI } = require('@google/generative-ai');

const app = express();
const supabase = createClient(
  process.env.SUPABASE_URL,
  //process.env.SUPABASE_KEY
  process.env.SUPABASE_SERVICE_ROLE_KEY

);

// Gemini API Configuration
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

// LINE Developers Console settings
const config = {
  channelAccessToken: process.env.LINE_CHANNEL_ACCESS_TOKEN || "",
  channelSecret: process.env.LINE_CHANNEL_SECRET || ""
};

const client = new line.Client(config);

app.use('/webhook', line.middleware(config));

// Receive webhook
app.post('/webhook', (req, res) => {
  Promise
    .all(req.body.events.map(handleEvent))
    .then(result => res.json(result));
});

async function handleImageMessage(event) {
  const messageId = event.message.id;

  try {
    // ดึงไฟล์จาก LINE
    const stream = await client.getMessageContent(messageId);

    // แปลง stream → buffer
    const chunks = [];
    for await (const chunk of stream) {
      chunks.push(chunk);
    }
    const buffer = Buffer.concat(chunks);

    // อัพโหลดเข้า Supabase Storage
    const fileName = `line_images/${messageId}.jpg`;
    const { data, error } = await supabase.storage
      .from("uploads") // ชื่อ bucket
      .upload(fileName, buffer, {
        contentType: "image/jpeg",
        upsert: true, // ถ้ามีไฟล์ชื่อซ้ำ จะเขียนทับ
      });

    if (error) {
      console.error("❌ Upload error:", error);
      return client.replyMessage(event.replyToken, {
        type: "text",
        text: "อัปโหลดรูปไป Supabase ไม่สำเร็จ",
      });
    }

    console.log("✅ Uploaded to Supabase:", data);

    // ตอบกลับ User
    return client.replyMessage(event.replyToken, {
      type: "text",
      text: "📷 ได้รับรูปแล้ว และอัปโหลดไป Supabase สำเร็จ!",
    });
  } catch (err) {
    console.error("❌ Error:", err);
  }
}

// Reply to message
async function handleEvent(event) {
  if (event.type === "message" && event.message.type === "image") {
    return handleImageMessage(event);
  }

  if (event.type !== 'message' || event.message.type !== 'text') {
    return Promise.resolve(null);
  }

  const userMessage = event.message.text;
  let replyContent = "ขอโทษค่ะ เกิดข้อผิดพลาดในการสร้างคำตอบ";

  try {
    const prompt = `กรุณาตอบคำถามนี้ให้สั้นและสร้างสรรค์: "${userMessage}"`;
    const result = await model.generateContent(prompt);
    const response = await result.response;
    replyContent = response.text();
  } catch (error) {
    console.error("Error generating content with Gemini:", error);
    replyContent = "ขอโทษค่ะ เกิดข้อผิดพลาดในการสร้างคำตอบ กรุณาลองใหม่อีกครั้ง";
  }

  return supabase
    .from("messages")
    .insert({
      user_id: event.source.userId,
      message_id: event.message.id,
      type: event.message.type,
      content: userMessage,
      reply_token: event.replyToken,
      reply_content: replyContent,
    })
    .then(({ error }) => {
      if (error) {
        console.error("Error inserting message:", error);
        return client.replyMessage(event.replyToken, {
          type: "text",
          text: "เกิดข้อผิดพลาดในการบันทึกข้อความ",
        });
      }
      return client.replyMessage(event.replyToken, {
        type: "text",
        text: replyContent,
      });
    });
}

app.get('/', (req, res) => {
  res.send('hello world, Somkiad');
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
});