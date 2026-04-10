import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { user_id } = await req.json()

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // --- ส่วนที่เพิ่มใหม่: ลบรูปภาพใน Storage ---
    
    // 1. ลบรูป Avatar (อ้างอิงชื่อไฟล์ที่เราตั้งตอนอัปโหลด: user_id_avatar.xxx)
    // เราจะดึงรายการไฟล์ที่ขึ้นต้นด้วย user_id มาแล้วลบทิ้งทั้งหมด
    const { data: avatarFiles } = await supabaseAdmin.storage.from('avatars').list('', {
      search: user_id
    });
    
    if (avatarFiles && avatarFiles.length > 0) {
      const filesToRemove = avatarFiles.map((f) => f.name);
      await supabaseAdmin.storage.from('avatars').remove(filesToRemove);
    }

    // 2. ลบรูปสินค้าในโฟลเดอร์ของผู้ใช้ (ถ้ามี)
    // ในไฟล์ post_item_page.dart เราเก็บรูปไว้ในโฟลเดอร์ตาม user_id
    const { data: productFiles } = await supabaseAdmin.storage.from('product_images').list(user_id);
    
    if (productFiles && productFiles.length > 0) {
      const filesToRemove = productFiles.map((f) => `${user_id}/${f.name}`);
      await supabaseAdmin.storage.from('product_images').remove(filesToRemove);
    }
    
    // --- สิ้นสุดส่วนลบรูปภาพ ---

    // ลบตัวตนในระบบ Authentication ถาวร
    const { error: authError } = await supabaseAdmin.auth.admin.deleteUser(user_id)
    if (authError) throw authError

    return new Response(JSON.stringify({ message: "Cleaned up storage and deleted auth successfully" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    })
  }
})