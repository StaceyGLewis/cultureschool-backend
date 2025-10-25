import type { Handler } from "@netlify/functions";
import jwt from "jsonwebtoken";

// Keep this list mirrored with your Supabase admin list if you want
const ADMIN_EMAILS = new Set([
  "info@cultureschool.org",
  "stacey.a.grant@gmail.com",
  "stacey@cococreate.app",
]);

export const handler: Handler = async (event) => {
  try {
    // You likely already have Supabase auth on admin; adapt this to your setup:
    // Example: pass email in a header/local cookie; here we accept x-admin-email for simplicity.
    const email = (event.headers["x-admin-email"] || "").toString().toLowerCase();
    if (!ADMIN_EMAILS.has(email)) {
      return { statusCode: 403, body: JSON.stringify({ error: "not_admin" }) };
    }
    const token = jwt.sign(
      { sub: email, role: "admin" },
      process.env.COCO_ADMIN_JWT_SECRET as string,
      { expiresIn: "10m", issuer: "coco-admin" }
    );
    return { statusCode: 200, body: JSON.stringify({ token }) };
  } catch (e: any) {
    return { statusCode: 500, body: JSON.stringify({ error: e?.message || "mint_failed" }) };
  }
};
