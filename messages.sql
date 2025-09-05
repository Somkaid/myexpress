create table messages (
  id uuid default gen_random_uuid() primary key,
  user_id varchar(255),
  message_id text not null,              -- LINE messageId
  type text not null,                    -- text, image, sticker, video
  content text,                          -- ข้อความหรือ URL ของไฟล์
  reply_token text,                      -- token สำหรับ reply
  reply_content text, 
  created_at timestamp default now()
);
